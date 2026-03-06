-- we use table materialization for now; daily incremental loading can be added as data volume grows

WITH base AS (

    SELECT
        block_date,
        source_chain,
        bridge,
        min_amount_usd,
        min_amount_eur,
        tx_sender
    FROM {{ ref('fct_lifi_transfers') }}

)

SELECT

    block_date,
    
    -- let's assume we'd like to calculate data by source chain and bridge. 
    source_chain,
    bridge,

    -- Starting point metrics; we can add more metrics here
    -- and decide whether to keep this aggregation in dbt
    -- or move parts of the logic into a BI tool.
    SUM(min_amount_usd) AS volume_usd,
    SUM(min_amount_eur) AS volume_eur,
    AVG(min_amount_usd) AS avg_volume_usd,
    AVG(min_amount_eur) AS avg_volume_eur,
    COUNT(*) AS transfers_count

FROM base
GROUP BY
    block_date,
    source_chain,
    bridge

