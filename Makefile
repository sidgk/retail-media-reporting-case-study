# All commands run from the repository root. Run `make help` for the list.
-include .env
DBT := cd dbt && $(HOME)/.venvs/dbt/bin/dbt

.PHONY: help load seed parse model test build airflow airflow-init demo

help:
	@grep -E '^[a-z-]+:.*##' Makefile | sed -E 's/:.*## /\t/'

load: ## Reload all three raw files (safe to rerun)
	$(HOME)/.venvs/dbt/bin/python ingestion/load_raw.py --date 2025-07-01

seed: ## Load the gender mapping
	$(DBT) seed

parse: ## Check the project compiles
	$(DBT) parse

model: ## Build and test one model: make model m=prep_teasers_cms
	$(DBT) build --select $(m)

test: ## Run every test against your models
	$(DBT) test

build: ## Rebuild and test everything
	$(DBT) build

demo: ## Run all three DAGs for 7 June, safe to repeat because unchanged data is skipped
	bash -c 'source orchestration/env.sh && for d in rtm_ingestion rtm_dbt_models rtm_dbt_tests; do airflow dags unpause $$d; done && airflow dags trigger rtm_ingestion -e "2025-06-08T$$(date +%H:%M:%S)+00:00"'

airflow-init: ## First-time Airflow setup
	bash -c 'source orchestration/env.sh && airflow db migrate'

airflow: ## Start Airflow at http://localhost:8080
	bash orchestration/start_airflow.sh
