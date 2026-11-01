"""Starts each Airflow task as a new process instead of forking the current one.

On macOS 27 a forked task process hangs at 100% CPU. Starting fresh is slower by a second or two,
which does not matter here. Needed for this laptop only, not for production on Linux.
"""
from airflow.task.task_runner.standard_task_runner import StandardTaskRunner


class ExecTaskRunner(StandardTaskRunner):
    def start(self):
        self.process = self._start_by_exec()
