"""Step 2 of 3: build prep, then intermediate, then marts, then start the tests.

One DAG with three tasks, because the layers must always run together and in this order.
Started by rtm_ingestion. Run it alone to rebuild models without reloading sources.
"""
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.trigger_dagrun import TriggerDagRunOperator

from rtm_common import DBT, DEFAULT_ARGS, START_DATE, VARS

with DAG(
    dag_id="rtm_dbt_models",
    description="Build the prep, intermediate and marts models",
    schedule=None,
    start_date=START_DATE,
    catchup=False,
    max_active_runs=1,  # two runs replacing the same partitions must never overlap
    is_paused_upon_creation=True,
    tags=["retail_media", "daily", "prep", "intermediate", "marts"],
    default_args=DEFAULT_ARGS,
) as dag:
    run_prep = BashOperator(task_id="dbt_run_prep", bash_command=f"{DBT} run --select tag:prep {VARS}")

    run_intermediate = BashOperator(
        task_id="dbt_run_intermediate",
        bash_command=f"{DBT} run --select tag:intermediate {VARS}",
    )

    run_marts = BashOperator(task_id="dbt_run_marts", bash_command=f"{DBT} run --select tag:marts {VARS}")

    start_tests = TriggerDagRunOperator(
        task_id="start_tests",
        trigger_dag_id="rtm_dbt_tests",
        logical_date="{{ logical_date }}",
        reset_dag_run=True,
    )

    run_prep >> run_intermediate >> run_marts >> start_tests
