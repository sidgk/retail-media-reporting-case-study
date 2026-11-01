#!/usr/bin/env bash
# Rebuilds the local Airflow install. Already done on this Mac; only needed on a new machine.
set -euo pipefail
AIRFLOW_VERSION=2.11.0
uv venv --python 3.12 --quiet "$HOME/.venvs/airflow"
PY="$HOME/.venvs/airflow/bin/python"
uv pip install --quiet --python "$PY" "apache-airflow==${AIRFLOW_VERSION}" \
  --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-3.12.txt"
# setproctitle segfaults after fork() on macOS 27, which kills every gunicorn worker. It only
# renames processes, so a no-op replacement is safe.
uv pip uninstall --quiet --python "$PY" setproctitle
SITE="$("$PY" -c 'import site; print(site.getsitepackages()[0])')"
cat > "$SITE/setproctitle.py" <<'PYEOF'
"""No-op stand-in. The real library segfaults after fork() on macOS 27, and it only renames processes."""
__version__ = "0-noop"


def setproctitle(title):
    pass


def getproctitle():
    return ""
PYEOF
