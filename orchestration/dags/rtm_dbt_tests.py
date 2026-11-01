"""Step 3 of 3: check freshness, then test everything once all models are built.

Kept separate so a failed test is a clear signal on its own, and tests can rerun without rebuilding.
Started by rtm_dbt_models.
"""
from airflow import DAG
from airflow.operators.bash import BashOperator

from rtm_common import DBT, DEFAULT_ARGS, START_DATE, VARS

with DAG(
    dag_id="rtm_dbt_tests",
    description="Check source freshness and run all dbt tests",
    schedule=None,
    start_date=START_DATE,
    catchup=False,
    max_active_runs=1,
    is_paused_upon_creation=True,
    tags=["retail_media", "daily", "tests"],
    default_args=DEFAULT_ARGS,
) as dag:
    freshness = BashOperator(task_id="dbt_source_freshness", bash_command=f"{DBT} source freshness")

    test = BashOperator(task_id="dbt_test", bash_command=f"{DBT} test {VARS}")

    freshness >> test
