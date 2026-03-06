"""
LI.FI Data Ingestion
Loads transfer events, token USD prices, and FX rates into a local DuckDB database.
"""

import os
import time
import duckdb
import pandas as pd
import requests
from functools import partial
from dotenv import load_dotenv
from dune_client.client import DuneClient
from dune_client.query import QueryBase

load_dotenv()

DB_PATH = "data/lifi.duckdb"
DUNE_QUERY_ID = 6791796
BATCH_SIZE = 250_000
SLEEP_BETWEEN_CALLS = 1.5  # seconds — avoids 429 rate limits
FIXER_API_KEY = os.environ["FIXER_API_KEY"]

def load_transfers(con: duckdb.DuckDBPyConnection) -> None:
    """Load raw LI.FI transfer events from CSV into DuckDB."""
    print("Loading transfers ...")
    con.execute("""
        CREATE OR REPLACE TABLE raw_lifi_transfers AS
        SELECT * FROM read_csv_auto('data/lifi_transfers_raw.csv')
    """)
    count = con.execute("SELECT count(*) FROM raw_lifi_transfers").fetchone()[0]
    print(f"  Loaded {count:,} rows → raw_lifi_transfers")


def load_token_prices(con: duckdb.DuckDBPyConnection) -> None:
    """Load token USD prices from Dune Analytics into DuckDB.
    Uses cached results (no re-execution) and paginates with sleep to avoid 429s.
    """

    dune = DuneClient()
    query = QueryBase(name="USD Token Prices", query_id=DUNE_QUERY_ID)

    # use cached results — 1-row fetch just to get execution_id without re-running the query
    result = dune.get_latest_result(query, sample_count=1)
    job_id = result.execution_id
    print(f"  Execution ID: {job_id}")

    offset, batch_num = 0, 0
    while True:
        print(f"  Fetching batch {batch_num + 1} (offset {offset:,}) ...")
        batch = dune.get_execution_results_csv(job_id, limit=BATCH_SIZE, offset=offset)
        batch.data.seek(0)
        df = pd.read_csv(batch.data)

        if batch_num == 0:
            con.execute("CREATE OR REPLACE TABLE raw_token_usd_prices AS SELECT * FROM df")
        else:
            con.execute("INSERT INTO raw_token_usd_prices SELECT * FROM df")

        batch_num += 1
        if batch.next_offset is None:
            break
        offset = int(batch.next_offset)
        time.sleep(SLEEP_BETWEEN_CALLS)

    count = con.execute("SELECT count(*) FROM raw_token_usd_prices").fetchone()[0]
    print(f"  Loaded {count:,} rows → raw_token_usd_prices")


def load_fx_rates(con: duckdb.DuckDBPyConnection, start_date: str, end_date: str) -> None:
    """Load daily USD/GBP→EUR FX rates from Fixer.io into DuckDB.
    Fixer free tier returns EUR as base, so rates are inverted to get X→EUR.
    """
    print(f"Loading FX rates ({start_date} → {end_date}) ...")

    rows = []
    for date in pd.date_range(start_date, end_date):
        date_str = date.strftime("%Y-%m-%d")
        try:
            resp = requests.get(
                f"https://data.fixer.io/api/{date_str}",
                params={"access_key": FIXER_API_KEY, "symbols": "USD"},
                timeout=10,
            ).json()
        except requests.RequestException as e:
            print(f"  Warning: {date_str} — request failed: {e}")
            continue

        if not resp.get("success"):
            print(f"  Warning: {date_str} — {resp.get('error', {}).get('info')}")
            continue

        # invert: response gives EUR→X; we store X→EUR for downstream USD-to-EUR conversion
        rows.extend(
            {"rate_date": date_str, "base_currency": cur, "target_currency": resp["base"], "rate": 1 / rate}
            for cur, rate in resp["rates"].items()
        )
        time.sleep(SLEEP_BETWEEN_CALLS)

    if not rows:
        print("  Warning: no FX rates fetched — skipping table creation")
        return

    df = pd.DataFrame(rows)
    con.execute("CREATE OR REPLACE TABLE raw_fx_rates AS SELECT * FROM df")
    print(f"  Loaded {len(df):,} rows → raw_fx_rates")


def main():
    loaders = [
        ("transfers", load_transfers),
        ("token_prices", load_token_prices),
        ("fx_rates", partial(load_fx_rates, start_date="2026-02-01", end_date="2026-02-11")),
    ]
 
    with duckdb.connect(DB_PATH) as con:
        for name, loader in loaders:
            try:
                loader(con)
            except Exception as e:
                print(f"Error loading {name}: {e}")
 
    print("Done.")


if __name__ == "__main__":
    main()
