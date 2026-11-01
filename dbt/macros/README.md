# Macros

Three small macros. A macro is a reusable piece of Jinja that dbt turns into SQL or config when it compiles a model.

| Macro | In plain words | Used by |
|---|---|---|
| `generate_schema_name` | Uses exact dataset names like `rtm_prep` | Every model, automatically |
| `day_partition` | One place to set how event tables are partitioned | `prep_tracking_events`, `int_campaign_events_daily`, `fact_campaign_performance_daily` |
| `event_window` | Limits a model to the event days it should read | `prep_tracking_events`, `int_campaign_events_daily` |

## `generate_schema_name`

By default dbt would name a dataset `<target>_<schema>`, which gives `rtm_dev_rtm_prep`. This replaces that behaviour, so `+schema: rtm_prep` in `dbt_project.yml` gives exactly `rtm_prep`.

## `day_partition`

Returns the `partition_by` setting.

| `use_date_partitions` var | Partitions on | When |
|---|---|---|
| `false` (current) | `event_day`, an integer day number | BigQuery sandbox |
| `true` | `event_date`, a native date | Production, needs billing. Not tested here |

A sandbox silently removes date partitions older than 60 days, which would delete June 2025 rows. An integer partition avoids that.

It also sets `copy_partitions: true`. dbt then replaces whole partitions with BigQuery's copy API instead of `MERGE`, which a sandbox blocks.

## `event_window`

Returns the `where` condition on event days.

| Run type | Reads |
|---|---|
| Normal incremental run | `run_date` and the `lookback_days` before it |
| First build of a table | Everything from `start_date` |

With `run_date` 2025-06-08 and `lookback_days` 3, it compiles to:

```sql
event_day between unix_date(date '2025-06-08') - 3
              and unix_date(date '2025-06-08')
```

This is what keeps a source of over 1 TB a day affordable. It also handles GA4 late data, because each run rebuilds the last 3 days. To backfill:

```bash
dbt run --select prep_tracking_events+ --vars '{run_date: "2025-06-08", lookback_days: 30}'
```

Airflow passes `run_date` on each run. The vars are defined in `dbt_project.yml`.

## From the dbt_utils package

These aren't written here, but the project uses them:

| Macro | Used for |
|---|---|
| `generate_surrogate_key` | Building `campaign_key`, `event_id` and `placement_line_id` |
| `unique_combination_of_columns` | Testing that a table's grain has no duplicates |
| `expression_is_true` | Testing a rule on every row |
| `accepted_range` | Testing that a number is within limits |
