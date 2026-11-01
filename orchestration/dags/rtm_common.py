"""Settings shared by the three retail media DAGs."""
import os
from datetime import datetime, timedelta

ROOT = os.environ["RETAIL_MEDIA_ROOT"]
PROJECT = os.environ["GCP_PROJECT"]
PYTHON = "$HOME/.venvs/dbt/bin/python"
DBT = f"cd {ROOT}/dbt && $HOME/.venvs/dbt/bin/dbt"
VARS = """--vars '{"run_date": "{{ ds }}"}'"""
START_DATE = datetime(2025, 6, 7)
DEFAULT_ARGS = {
    "retries": 2,
    "retry_delay": timedelta(minutes=10),
    "execution_timeout": timedelta(hours=1),
}
