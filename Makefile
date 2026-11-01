# All commands run from the repository root. Run `make help` for the list.
-include .env
DBT := cd dbt && $(HOME)/.venvs/dbt/bin/dbt

.PHONY: help load seed parse model test build airflow airflow-init

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

airflow-init: ## First-time Airflow setup
	bash -c 'source orchestration/env.sh && airflow db migrate'

airflow: ## Start Airflow at http://localhost:8080
	bash orchestration/start_airflow.sh
