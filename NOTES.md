# Assessment Notes & Trade-offs

## What I would do with more time (Production Readiness)

- **Incremental materialization** for `fct_lifi_transfers` — currently full-table rebuild; would switch to incremental as data volume grows
- **Better price coverage** — use an additional API (e.g. CoinGecko) to fill tokens/chains not covered by Dune's `prices.usd`
- **Token metadata table** — build a separate table (contract_address → symbol + decimals) from an external API, then join prices by symbol + timestamp instead of contract_address; this decouples decimals from the price source and makes gap-filling easier
- **Forward-fill missing prices** by symbol using a window function — though this is tricky since we currently rely on `decimals` from the price table to compute amounts, so a missing price row also means missing decimals (the metadata table above would solve this)
- **Separate schemas** per layer (staging, marts) instead of a flat structure
- **Modular ingestion script** — currently `duckdb_creation.py` is a single file with all three loaders.
  - With more data sources it should be split into separate modules per source (e.g. `loaders/transfers.py`, `loaders/prices.py`, `loaders/fx_rates.py`) with a shared config and a CLI entrypoint.
  - For Dune data we insert each batch immediately; in production we could accumulate chunks in a DataFrame and bulk-load at the end, or use webhooks (if available) to avoid polling.
  - Fixer and Dune data should be loaded incrementally rather than full reloads.
  - Fixer free tier only provides daily rates; using a paid API with minute-level FX rates would improve report accuracy.
- **Additional context data** to enrich transfer analysis:
  - *Crypto Fear & Greed Index* — daily sentiment score; could correlate with bridge volume spikes (panic selling → more cross-chain movement)
  - *Gas prices per chain* — high gas on Ethereum often drives users to bridge to L2s; would help explain volume shifts between chains
  - *Bridge protocol TVL / liquidity* — from DefiLlama; explains why certain bridges are preferred on certain days
  - *Major token events* (listings, depegs, airdrops) — categorical flags that explain volume outliers


## Known Issues / Data Anomalies

- **693 transfers (~3%) have NULL USD/EUR amounts** — Dune's `prices.usd` does not cover every timestamp/token/chain combination. `SUM()` in `daily_transfers_metrics` skips NULLs, so volume metrics only reflect transfers with known prices
- **bob chain** has no wrapped token in Dune's price feed → native token transfers on bob are always unpriced

## Design Decisions & Simplifications

| Decision | Why |
|----------|-----|
| **Flat `marts/` folder** | Only 2 models — sub-nesting (silver/gold) would be over-engineering |
| **No intermediate layer** | Joins are straightforward enough to handle directly in the fact table |
| **Seed CSV for native token mapping** | Static data, rarely changes, easy to review in version control |
| **Views for staging** | Dataset is small, no performance need to materialize; keeps storage lean |
| **Table materialization for marts** | One-time batch load; incremental would add complexity with no benefit at this scale |
| **Daily FX rates** | Fixer.io free tier is daily — sufficient granularity for bridge transfer volumes |
| **`CREATE OR REPLACE` in ingestion** | Idempotent re-runs, appropriate for a batch script that is not scheduled |

## AI Usage Statement

Used Claude Code throughout the project as a pair-programming partner. Specific areas where AI assisted:

- **dbt project structure**: initial scaffolding (`dbt_project.yml`, `profiles.yml`, source definitions), staging model SQL for JSON unpacking, seed CSV for native token mapping, column naming conventions
- **dbt tests & docs**: column descriptions, `dbt_utils.unique_combination_of_columns` grain tests, `expression_is_true` range validations, source freshness configuration
- **Data model design doc** (`task_1/data_model_description.md`): diagram layout, structuring the written description
- **Code review**: reviewed both the dbt project and ingestion script, identified issues (missing `models:` block in `dbt_project.yml`, inconsistent layer naming, missing composite uniqueness tests), then helped fix them