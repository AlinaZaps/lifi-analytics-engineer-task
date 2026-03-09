WITH token_prices AS (

    SELECT * FROM {{ source('raw', 'raw_token_usd_prices') }}

)

SELECT
    CAST(minute AS TIMESTAMP) AS price_time,
    blockchain,
    contract_address,
    symbol,
    decimals,
    price AS price_usd
FROM token_prices
