# LI.FI Analytics Engineer - Take-Home Assessment

Welcome! This assessment consists of three connected tasks that progressively build on each other. You are expected to spend approximately **4–6 hours** in total. We value clarity and thoughtfulness over completeness—if you run out of time, document what you would have done differently.

Assume that the company's reporting currency is **EUR**.

## Data Sources

1. **LiFi Transfer Events (on-chain, per-block)**
   * **Source:** Dune Analytics (`lifi_multichain.LiFiDiamond_v2_evt_LiFiTransferStarted`)
   * *Fallback provided:* To save you time and prevent Dune API rate limits, we have provided a sample of ~20k rows in the `/data` folder. You can use this directly.
   * *Consideration:* The `sendingAssetId` field uses a zero-address (`0x000...000`) as a placeholder for native tokens (ETH, MATIC, etc.). Think about what this means for downstream joins.

2. **Token Prices in USD**
   * **Source:** Dune Analytics (`prices.usd`) or any free API (CoinGecko, etc.)
   * You must source this data yourself. Automating the extraction via an API is a **huge plus**, but if you hit rate limits, you can download it manually and place it in the `/data` folder.

3. **External Source [BONUS]**
   * **Source:** E.g., Crypto Fear & Greed Index API (https://api.alternative.me/fng/?limit=0)
   * This is an optional bonus dataset. Focus on the core transfers and prices first.

---

## Task 1: Data Model Design
**Deliverable:** A written description + a simple diagram in the `/task_1` folder.

Propose an analytical data model structure suitable for a transformation tool like dbt or SQLMesh.
* **Layering:** How would you organize your layers?
* **Grain & Joins:** How do transfers connect to prices?
* **Currency:** How would you approach EUR conversion?

## Task 2: Data Ingestion
**Deliverable:** Working scripts in the `/ingestion` folder.

Load the data sources into a local **DuckDB** database. 
* DuckDB can natively read CSVs. You don't need a complex pipeline; a simple Python script or COPY statements work fine. The goal is to get clean, queryable tables.

## Task 3: Transformation Project
**Deliverable:** A working dbt or SQLMesh project in the `/dbt_project` folder.

Transform the raw data into an analytical model.
* **Staging:** Clean and type-cast. The `bridgeData` JSON column needs to be unpacked.
* **Marts:** Join transfers with prices, calculate volumes (remembering crypto nuances).
* **Tests & Docs:** Define meaningful tests and descriptions.

---

## Submission
Please submit your work as a Git repository (GitHub/GitLab link or a zip archive). 
If you use AI assistants, that's perfectly fine—just be ready to explain and defend every design decision during the walkthrough session!