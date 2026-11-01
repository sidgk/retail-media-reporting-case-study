"""Loads the three source files into rtm_raw.

Every column stays STRING: raw means exactly what the source sent. Type detection would turn
campaign_id 000329 into 329 and break the join to the CMS.

- CMS and Salesforce are full daily copies, one partition per snapshot day. The CMS deletes old
  campaigns, so these copies are the only history we will ever have.
- Events load into one partition per event day.
- Rerunning a date replaces its partition, never appends a second copy.
- Partitions are integer ranges on UNIX_DATE, because a BigQuery sandbox silently expires DATE
  partitions older than 60 days. Load jobs and query destinations are used instead of DML.

Usage: python ingestion/load_raw.py --date 2025-07-01 [--source-dir data/source] [--skip-events]
"""
import argparse
import os
import pathlib
from datetime import date

from google.cloud import bigquery

ROOT = pathlib.Path(__file__).resolve().parent.parent
LOCATION = "EU"
DATASET = "rtm_raw"

SNAPSHOT_SOURCES = {
    "teasers_cms": ["campaign_id", "campaign_name", "gender", "active_from", "active_to"],
    "online_placements_salesforce": [
        "campaign_start", "campaign_end", "gender", "country_cluster", "reach", "currency_cpm",
        "cpm", "benchmark_ctr", "benchmark_clicks", "campaign_name",
    ],
}
EVENT_SOURCE = "tracking_events"
EVENT_COLUMNS = [
    "session_id", "visitor_id", "device", "event_timestamp", "event_type", "campaign_id",
    "campaign_name", "campaign_type",
]


def read_env():
    env_file = ROOT / ".env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            if "=" in line and not line.startswith("#"):
                key, value = line.removeprefix("export ").split("=", 1)
                os.environ.setdefault(key.strip(), value.strip())


def run(client, sql, destination=None):
    config = bigquery.QueryJobConfig()
    if destination:
        config.destination = destination
        config.write_disposition = "WRITE_TRUNCATE"
    return list(client.query(sql, job_config=config, location=LOCATION).result())


def create_table(client, table, columns, extra_columns, partition_column):
    ddl = ", ".join([f"{c} STRING" for c in columns] + extra_columns)
    run(client, f"""create table if not exists `{DATASET}.{table}` ({ddl})
                    partition by range_bucket({partition_column}, generate_array(18000, 28000, 1))""")


def load_landing(client, table, path, columns):
    """Loads the file as it is. A changed column count fails here, on purpose."""
    landing = f"{client.project}.{DATASET}._landing_{table}"
    config = bigquery.LoadJobConfig(
        schema=[bigquery.SchemaField(c, "STRING") for c in columns],
        source_format=bigquery.SourceFormat.CSV,
        skip_leading_rows=1,
        allow_quoted_newlines=True,
        max_bad_records=0,
        write_disposition="WRITE_TRUNCATE",
    )
    with open(path, "rb") as f:
        job = client.load_table_from_file(f, landing, job_config=config, location=LOCATION)
    job.result()
    if job.output_rows == 0:
        raise ValueError(f"{path.name} is empty, so the previous copy is left in place")
    return landing


def load_snapshot(client, table, columns, source_dir, snapshot_date):
    day = (snapshot_date - date(1970, 1, 1)).days
    file_name = f"{table}.csv"
    landing = load_landing(client, table, source_dir / file_name, columns)
    create_table(client, table, columns,
                 ["_snapshot_date DATE", "_snapshot_day INT64", "_source_file STRING", "_loaded_at TIMESTAMP"],
                 "_snapshot_day")
    run(client, f"""select *, date '{snapshot_date}' as _snapshot_date, {day} as _snapshot_day,
                           '{file_name}' as _source_file, current_timestamp() as _loaded_at
                    from `{landing}`""",
        destination=f"{client.project}.{DATASET}.{table}${day}")
    print(f"loaded {table}, snapshot {snapshot_date}")


def load_events(client, source_dir):
    file_name = f"{EVENT_SOURCE}.csv"
    landing = load_landing(client, EVENT_SOURCE, source_dir / file_name, EVENT_COLUMNS)
    create_table(client, EVENT_SOURCE, EVENT_COLUMNS,
                 ["event_day INT64", "_source_file STRING", "_loaded_at TIMESTAMP"], "event_day")
    day_sql = "unix_date(date(left(event_timestamp, 10)))"
    for row in run(client, f"select distinct {day_sql} as day from `{landing}` order by 1"):
        run(client, f"""select *, {day_sql} as event_day, '{file_name}' as _source_file,
                               current_timestamp() as _loaded_at
                        from `{landing}` where {day_sql} = {row.day}""",
            destination=f"{client.project}.{DATASET}.{EVENT_SOURCE}${row.day}")
        print(f"loaded {EVENT_SOURCE}, partition {row.day}")


def main():
    parser = argparse.ArgumentParser(description="Load the source files into rtm_raw")
    parser.add_argument("--date", type=date.fromisoformat, required=True, help="snapshot date")
    parser.add_argument("--source-dir", type=pathlib.Path, default=ROOT / "data" / "source")
    parser.add_argument("--skip-events", action="store_true",
                        help="copy only the CMS and the sheet, for when GA4 exports by itself")
    args = parser.parse_args()

    read_env()
    client = bigquery.Client(project=os.environ["GCP_PROJECT"], location=LOCATION)
    for table, columns in SNAPSHOT_SOURCES.items():
        load_snapshot(client, table, columns, args.source_dir, args.date)
    if not args.skip_events:
        load_events(client, args.source_dir)


if __name__ == "__main__":
    main()
