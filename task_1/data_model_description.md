# Data Model Design

## Layering

```
 Raw (DuckDB)            Staging (dbt views)              Marts (dbt tables)
 ────────────            ───────────────────              ──────────────────

 raw_lifi_transfers   →  stg_lifi_transfers     ──┐
                                                  │
 raw_token_usd_prices →  stg_token_usd_prices   ──┤
                                                  ┼──→  fct_lifi_transfers  ──→  daily_transfers_metrics
 raw_fx_rates         →  stg_fiat_daily_rates   ──┤
                                                  │
                         native_token_mapping   ──┘
                         (seed)
```

**Staging** — views that clean, rename, and type-cast raw sources. The `bridgeData` JSON column is unpacked here into individual typed columns. No business logic, no joins — just a clean interface on top of raw data.

**Marts** — materialized tables where joins and calculations happen. Two models:
- `fct_lifi_transfers` — one row per transfer event, enriched with USD/EUR pricing
- `daily_transfers_metrics` — aggregated volumes and counts by date, chain, and bridge

**Seeds** — `native_token_mapping.csv` maps native token zero-addresses to their wrapped token contract addresses per chain.

No intermediate layer — the project has only one fact table with straightforward joins, so an extra layer would add folders without adding clarity.

**Data volumes:** ~20k transfer events, ~1.1M price rows (minute-level from Dune), ~20 FX rate rows. Small enough that views for staging and full-table materialization for marts work without performance concerns.

---

## Grain & Joins

### Transfer grain

One row per `(tx_hash, log_index)` — a single transaction can emit multiple LI.FI transfer events, so `tx_hash` alone is not unique.

### Price join

Transfers connect to prices through a three-step join:

```
transfers
    │
    ├── LEFT JOIN native_token_mapping
    │       ON (source_chain, token_address)
    │       → resolves zero-address to wrapped contract address
    │
    ├── LEFT JOIN stg_token_usd_prices
    │       ON (blockchain, COALESCE(wrapped_address, token_address), minute)
    │       → matches transfer to its token price at that minute
    │
    └── LEFT JOIN stg_fiat_daily_rates
            ON (block_date)
            → attaches the USD→EUR rate for that day
```

**Native token problem**: on-chain events use `0x000...000` for native tokens (ETH, xDAI, etc.), but price feeds use the wrapped token contract address. A seed CSV maps each chain's zero-address to its wrapped equivalent (e.g., arbitrum → WETH `0x82af...`). The join uses `COALESCE(wrapped_address, token_address)` so non-native tokens pass through unchanged.

**All joins are LEFT** — transfers are preserved even when no price or FX rate match exists. This means `min_amount_usd` and `min_amount_eur` can be NULL (see [NOTES.md](/NOTES.md) for details on NULL coverage and improvement ideas).

---

## Currency Conversion

The reporting currency is EUR. The conversion happens in two steps inside `fct_lifi_transfers`:

```
                 raw amount (token units)
                         │
                         ▼
            amount / 10^decimals × price_usd
                         │
                         ▼
                    min_amount_usd
                         │
                         ▼
              min_amount_usd × fx_rate
                         │
                         ▼
                    min_amount_eur
```

- **Decimal adjustment**: on-chain amounts are stored as integers in the token's smallest unit (e.g., 18 decimals for ETH). `COALESCE(decimals, 18)` handles tokens without metadata.
- **USD price**: matched at minute-level granularity from Dune's `prices.usd`.
- **FX rate**: Fixer.io free tier returns EUR-based rates (EUR→USD). These are inverted at ingestion time to get USD→EUR, then joined on `block_date` in the fact table.

