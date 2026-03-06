WITH lifi_transfers AS (

    SELECT * FROM {{ source('raw', 'raw_lifi_transfers') }}

)

SELECT
    -- transaction & block
    evt_tx_hash                                                     AS tx_hash,
    evt_index                                                       AS log_index,
    evt_tx_from                                                     AS tx_sender,
    evt_tx_to                                                       AS tx_recipient,
    evt_tx_index                                                    AS tx_index,
    evt_block_number                                                AS block_number,
    evt_block_date                                                  AS block_date,
    evt_block_time                                                  AS block_timestamp,

    -- chain & contract
    chain                                                           AS source_chain,
    contract_address                                                AS lifi_contract_address,

    -- unpacked bridgeData JSON
    bridgeData::JSON->>'transactionId'                              AS lifi_transaction_id,
    bridgeData::JSON->>'bridge'                                     AS bridge,
    bridgeData::JSON->>'integrator'                                 AS integrator,
    bridgeData::JSON->>'referrer'                                   AS referrer,
    bridgeData::JSON->>'sendingAssetId'                             AS token_address,
    bridgeData::JSON->>'receiver'                                   AS bridge_receiver,
    CAST(bridgeData::JSON->>'minAmount'           AS HUGEINT)       AS min_amount_raw,
    CAST(bridgeData::JSON->>'destinationChainId'  AS bigint)        AS destination_chain_id,
    CAST(bridgeData::JSON->>'hasSourceSwaps'      AS boolean)       AS has_source_swaps,
    CAST(bridgeData::JSON->>'hasDestinationCall'  AS boolean)       AS has_destination_call
FROM lifi_transfers