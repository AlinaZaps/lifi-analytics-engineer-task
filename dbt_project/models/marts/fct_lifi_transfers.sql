WITH transfers AS (

    SELECT
        tx_hash,
        log_index,
        tx_sender,
        tx_recipient,
        tx_index,
        block_number,
        block_date,
        block_timestamp,
        source_chain,
        lifi_contract_address,
        lifi_transaction_id,
        bridge,
        integrator,
        referrer,
        token_address,
        bridge_receiver,
        min_amount_raw,
        destination_chain_id,
        has_source_swaps,
        has_destination_call
    FROM {{ ref('stg_lifi_transfers') }}

)

, token_mapping AS (

    SELECT * FROM {{ ref('stg_seed__native_token_mapping') }}

)

, usd_prices AS (

    SELECT * FROM {{ ref('stg_token_usd_prices') }}

)

, fiat_rates AS (

    SELECT * FROM {{ ref('stg_fiat_daily_rates') }}
    WHERE base_currency = 'USD'
    AND target_currency = 'EUR'

)

SELECT
    -- primary key
    transfers.tx_hash,

    -- transaction identifiers & timing
    transfers.lifi_transaction_id,
    transfers.block_timestamp,
    transfers.block_date,
    transfers.block_number,


    -- routing / chains
    transfers.source_chain,
    transfers.destination_chain_id,
    transfers.lifi_contract_address,
    transfers.bridge,
    transfers.integrator,
    transfers.referrer,

    -- token & pricing
    (CAST(transfers.min_amount_raw AS DOUBLE)
        -- there is no way 0 would appear here, but it's a good practice to use defensive pattern
        / NULLIF(POW(10, COALESCE(usd_prices.decimals, 18)), 0)
        * usd_prices.price_usd) AS min_amount_usd,
    (CAST(transfers.min_amount_raw AS DOUBLE)
        -- there is no way 0 would appear here, but it's a good practice to use defensive pattern
        / NULLIF(POW(10, COALESCE(usd_prices.decimals, 18)), 0)
        * usd_prices.price_usd
        * fiat_rates.rate) AS min_amount_eur,
    transfers.token_address,
    usd_prices.price_usd,
    transfers.bridge_receiver,
    transfers.min_amount_raw,
    usd_prices.symbol,

    -- actors & flags
    transfers.tx_sender,
    transfers.tx_recipient,
    transfers.has_source_swaps,
    transfers.has_destination_call,

    -- technical indices
    transfers.log_index,
    transfers.tx_index

FROM transfers
-- map native tokens (zero-address) to their wrapped contract_address via seed
-- so we can join to usd prices
LEFT JOIN token_mapping
    ON transfers.source_chain = token_mapping.chain
    AND transfers.token_address = token_mapping.contract_address
LEFT JOIN usd_prices
    ON COALESCE(token_mapping.wrapped_contract_address, transfers.token_address) = usd_prices.contract_address
    AND transfers.source_chain=usd_prices.blockchain
    AND date_trunc('minute', transfers.block_timestamp) = usd_prices.price_time
LEFT JOIN fiat_rates
    ON transfers.block_date=fiat_rates.rate_date
