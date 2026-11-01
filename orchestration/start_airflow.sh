#!/usr/bin/env bash
# Starts Airflow on http://localhost:8080. Ctrl-C stops both processes.
# Not `airflow standalone`: its gunicorn workers crash after fork() on macOS 27. The --debug web
# server uses threads instead of forked workers. That is fine for one person on a laptop, and it
# is not how production would run.
set -euo pipefail
source "$(dirname "$0")/env.sh"
airflow db migrate >/dev/null
airflow scheduler &
SCHEDULER=$!
trap 'kill $SCHEDULER 2>/dev/null || true' EXIT
echo "Login user: admin. Password file: $AIRFLOW_HOME/standalone_admin_password.txt"
airflow webserver --debug --port 8080
