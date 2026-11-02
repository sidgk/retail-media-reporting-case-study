"""Step 1 of 3: load sources, wait for events, load reference data, then start the models.

Kept separate because loading depends on outside systems, so a late source never blocks a rerun of
the models. The logical date ({{ ds }}) is the day being processed.
"""
import os

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from airflow.sensors.bash import BashSensor

from rtm_common import DBT, DEFAULT_ARGS, PROJECT, PYTHON, ROOT, START_DATE

with DAG(
    dag_id="rtm_ingestion",
    description="Load the three sources and the brand seed",
    # Runs only when triggered locally. Production sets RTM_SCHEDULE, for example "0 12 * * *".
    schedule=os.environ.get("RTM_SCHEDULE"),
    start_date=START_DATE,
    catchup=False,
    max_active_runs=1,
    is_paused_upon_creation=True,
    tags=["retail_media", "daily", "ingestion"],
    default_args=DEFAULT_ARGS,
) as dag:
    # Copy the CMS and the sheet first, even if GA4 is late: a missed CMS copy can never be recovered.
    # In production GA4 exports itself into BigQuery, so this step would add --skip-events.
    ingest_raw = BashOperator(
        task_id="ingest_raw",
        bash_command=f"{PYTHON} {ROOT}/ingestion/load_raw.py --date {{{{ ds }}}}",
    )

    # GA4 publishes no fixed delivery time, so wait for the data rather than trust a clock.
    wait_for_events = BashSensor(
        task_id="wait_for_events",
        bash_command=(
            f"bq --location=EU query --project_id={PROJECT} --use_legacy_sql=false --format=csv --quiet "
            "\"select count(*) from rtm_raw.tracking_events "
            "where event_day = unix_date(date '{{ ds }}')\" | tail -1 | grep -qv '^0$'"
        ),
        mode="reschedule",  # frees the worker slot between checks
        poke_interval=30 * 60,
        timeout=12 * 60 * 60,
    )

    seed = BashOperator(task_id="dbt_seed", bash_command=f"{DBT} seed")

    start_models = TriggerDagRunOperator(
        task_id="start_models",
        trigger_dag_id="rtm_dbt_models",
        logical_date="{{ logical_date }}",
        reset_dag_run=True,
    )

    ingest_raw >> wait_for_events >> seed >> start_models
