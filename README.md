# Retail media reporting

A pipeline that turns GA4 events, a CMS and a manually maintained Salesforce sheet into one campaign performance table, with impressions, CTR and benchmark CTR by date, campaign, device and gender.

Built on BigQuery, dbt Core and Airflow.

## Deliverables

| Goal | Where |
|---|---|
| Pipeline design | [docs/02_PIPELINE_DESIGN.md](docs/02_PIPELINE_DESIGN.md) |
| SQL for the data model | [dbt/models](dbt/models), [docs/05_MODEL_GUIDE.md](docs/05_MODEL_GUIDE.md) |
| Governance and monitoring | [docs/03_GOVERNANCE_AND_MONITORING.md](docs/03_GOVERNANCE_AND_MONITORING.md) |
| Assumptions | [ASSUMPTIONS.md](ASSUMPTIONS.md) |
| Upstream recommendations | [docs/07_UPSTREAM_RECOMMENDATIONS.md](docs/07_UPSTREAM_RECOMMENDATIONS.md) |
| Backfill and late data | [docs/02_PIPELINE_DESIGN.md](docs/02_PIPELINE_DESIGN.md) |
| Manual sources | [docs/03_GOVERNANCE_AND_MONITORING.md](docs/03_GOVERNANCE_AND_MONITORING.md) |

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
```

`make airflow` starts Airflow locally. To run one layer, use a dbt tag, for example `dbt build --select tag:prep`. Tags: `prep`, `intermediate`, `marts`, `dim`, `fact`, `daily`. Airflow has three DAGs: `rtm_ingestion`, `rtm_dbt_models` and `rtm_dbt_tests`. The project was developed on a BigQuery sandbox, whose limits are listed in the pipeline design.
