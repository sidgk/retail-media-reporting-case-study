# Retail media reporting

A pipeline that turns GA4 events, a CMS and a manually maintained Salesforce sheet into one campaign performance table, with impressions, CTR and benchmark CTR by date, campaign, device and gender.

Built on BigQuery, dbt Core and Airflow.

## Deliverables

| Goal | Where |
|---|---|
| Pipeline design | [docs/pipeline_design.md](docs/pipeline_design.md) |
| SQL for the data model | [dbt/models](dbt/models), with a README in each layer |
| Governance and monitoring | [docs/governance_and_monitoring.md](docs/governance_and_monitoring.md) |
| Assumptions and questions | [ASSUMPTIONS.md](ASSUMPTIONS.md) |
| Upstream recommendations | [docs/upstream_recommendations.md](docs/upstream_recommendations.md) |
| Backfill and late data | [docs/pipeline_design.md](docs/pipeline_design.md) |
| Manual sources | [docs/governance_and_monitoring.md](docs/governance_and_monitoring.md) |

## Project layout

| Folder | Contents |
|---|---|
| `ingestion/` | Python script that loads the three files into raw |
| `dbt/` | Models, tests, macros and the brand seed |
| `orchestration/` | Airflow DAG |
| `docs/` | Documentation |

Source CSVs are not committed. Put them in `data/source/`.

## BigQuery datasets

`rtm_raw`, `rtm_prep`, `rtm_int`, `rtm_marts`, `rtm_seeds` and `rtm_audit`, in location EU.

## Running it

The project id is never committed. Copy the example, then set your own value in `.env`:

```bash
cp .env.example .env
source .env
```

SQL files use `dataset.table`, so select your project in the BigQuery console before running them.

```bash
make load
make seed
make build
make test
make demo
```

`make airflow` starts Airflow locally, and `make demo` then runs all three DAGs. To run one layer, use a dbt tag, for example `dbt build --select tag:prep`. Tags: `prep`, `intermediate`, `marts`, `dim`, `fact`, `daily`. Airflow has three DAGs: `rtm_ingestion`, `rtm_dbt_models` and `rtm_dbt_tests`. The project was developed on a BigQuery sandbox, whose limits are listed in the pipeline design.
