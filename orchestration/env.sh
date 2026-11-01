# Source this before any airflow command: source orchestration/env.sh
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/.." && pwd)"
[ -f "$ROOT/.env" ] && source "$ROOT/.env"
export AIRFLOW_HOME="$ROOT/orchestration/airflow_home"
export AIRFLOW__CORE__DAGS_FOLDER="$ROOT/orchestration/dags"
export AIRFLOW__CORE__LOAD_EXAMPLES=False
export AIRFLOW__WEBSERVER__WARN_DEPLOYMENT_EXPOSURE=False
export RETAIL_MEDIA_ROOT="$ROOT"
# macOS 27: a forked task process hangs at 100% CPU, so start each task as a new process.
export PYTHONPATH="$ROOT/orchestration/runner:${PYTHONPATH:-}"
export AIRFLOW__CORE__TASK_RUNNER=exec_task_runner.ExecTaskRunner
# macOS: without these two, Airflow's forked workers can crash.
export NO_PROXY="*"
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export PATH="$HOME/.venvs/airflow/bin:$PATH"
