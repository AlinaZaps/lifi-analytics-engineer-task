WITH fx_rates AS (

    SELECT * FROM {{ source('raw', 'raw_fx_rates') }}

)

SELECT
    CAST(rate_date AS DATE) AS rate_date,
    base_currency,
    target_currency,
    rate
FROM fx_rates

