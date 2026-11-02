# Pipeline design and decisions

Each decision states what we chose, why, and how it was tested.

**Labels used:** **[Tested]** ran in this project. **[Documented]** stated by a vendor. **[Assumption]** confirm with About You. **[Not tested]** designed but not run here.

## The architecture

```
 SOURCES                   RAW                  TRANSFORM                       REPORTING            USE

 GA4 export  ------------> tracking_events --> prep_tracking_events
 (>1 TB/day)               daily partitions        ad events only, deduped
                           immutable               incremental
                                                        |
                                                        v
                                                   int_campaign_events_daily
                                                   daily counts, incremental -----+
                                                                                  |
 CMS -------------------> teasers_cms -----------> prep_teasers_cms              v
 (deletes old rows)        full daily copies       last known version    --> int_campaign_ --> fact_campaign_  --> Dashboard
                                                                             context__daily    performance_daily
 Google Sheet ----------> online_placements_salesforce --> prep_online_placements_salesforce              ^            dim_campaign
 (manual)                  full daily copies       online_placements      ---------+
                                                   prep_online_placements_salesforce
                                                   rejected_rows (quarantine)

                       Airflow runs it daily. dbt tests guard each layer. Failures land in rtm_audit.
```

## Layers and naming

| Layer | BigQuery dataset | Prefix | Purpose | Materialization |
|---|---|---|---|---|
| Raw | `rtm_raw` | none | Exact copies, all STRING | Load jobs |
| Prep | `rtm_prep` | `prep_<source file name>` | Dedupe, typecast, basic tests. No business logic | Incremental for events, table otherwise |
| Intermediate | `rtm_int` | `int_<entity>_<grain>` | Shared business logic | Incremental for events, table otherwise |
| Marts | `rtm_marts` | `dim_`, `fact_` | What people query | Table |
| Audit | `rtm_audit` | test name | Rows that failed a test | Created by dbt |

**Naming rules:**

- A `prep_` model is the source file's name with the prefix added, so `teasers_cms.csv` becomes `rtm_raw.teasers_cms`, then `rtm_prep.prep_teasers_cms`. Anyone can trace a model to its source by name alone.
- Other layers use `int_`, `dim_` and `fact_`, with single underscores only.
- Datasets are `<business function>_<layer>`, and `rtm` means retail media.
- The full path is `project.dataset.model`. Production would be `analytics.rtm_marts.fact_campaign_performance_daily`. Here the project comes from `GCP_PROJECT`, because the BigQuery project ID `analytics` is already taken globally **[Tested]**.

An intermediate model exists only when it earns its place. There are two, both for a real reason:
- `int_campaign_events_daily` separates costly work from cheap work.
- `int_campaign_context_daily` is where new campaign types plug in.

## Decision 1: Keep unchanging events apart from changing metadata

**The single most important design choice.**

Events never change, but the sheet and CMS change often. If campaign details were joined into the event aggregation, each sheet correction would force rescanning events. At over 1 TB a day, that is unaffordable.

So event counts are built incrementally and hold no campaign details. A cheap final table joins them to the latest details.

**[Tested]** The fact table rebuilds from daily aggregates, 4,968 rows from 308,576 events.

## Decision 2: Match placements on name AND date

**[Tested]** Name only gives 388,276 impressions against 67,929 real. Adding the campaign dates date gives 69,171, with the rest handled by decision 3.

## Decision 3: Overlapping lines stay one row, labelled `mixed`

Tracking has no gender or country, so 2,766 impressions on 5 names cannot be assigned to one line. Options:

| Option | Problem |
|---|---|
| Duplicate rows per line | Inflates impressions |
| Split by reach | Invents precision. It reports a share nobody measured |
| **One row, `mixed`, reach-weighted benchmark** | Honest. Gender is less specific, and totals stay exact |

**[Tested]** Unit test `overlapping_lines_are_mixed_and_reach_weighted`.

## Decision 4: Daily raw copies instead of dbt snapshots

The CMS deletes rows, so history must be captured. A full copy of each small source goes into a daily partition in raw.

| | Daily raw copies | dbt snapshots |
|---|---|---|
| Change the history logic later | Yes, replay from raw | No, what was stored is final |
| Works on this sandbox | Yes | No, needs `MERGE` |
| Storage | Slightly higher, trivial at 5k and 20k rows | Lower |

The sandbox made this necessary, but it is defensible on its merits at this data size. If asked: at millions of rows, dbt snapshots with `hard_deletes: new_record` would be the better fit.

A second benefit: it answers "what did the sheet say on that date?" in a brand dispute.

**[Tested]** Unit test `newest_copy_is_kept_and_deleted_campaign_survives`. A deleted campaign keeps its gender.

## Decision 5: Benchmark rollup uses expected clicks

A CTR cannot be averaged. For any filter:

```
Benchmark CTR = sum(impressions x benchmark) / sum(impressions that have a benchmark)
```

So the table stores `expected_clicks` and `impressions_with_benchmark`, and the dashboard divides per campaign. This handles campaigns with several booked lines. Benchmarks are not blended across campaigns, because brands have different goals.

**Why `impressions_with_benchmark`:** without it, campaigns lacking a benchmark would drag the result down as if their benchmark were zero.

## Decision 6: Separate fact grain from filters

**Grain: one row per day, campaign and device.** Impressions, clicks and benchmarks all sum at that level. `target_gender` is a column on the fact, not only on the dimension, because for placements it can differ by day as lines start and stop. `dim_campaign` remains the governed list of campaigns.

## Decision 7: One set of datasets

Tables live once, in `rtm_raw`, `rtm_prep`, `rtm_int`, `rtm_marts`, `rtm_seeds` and `rtm_audit`. There are no parallel copies, so anyone reading the project sees one version of each table.

## Materialization choices, and why

| Model | Choice | Why |
|---|---|---|
| `prep_tracking_events` | Incremental, partition replace | Too large to rebuild. `allow_full_refresh` stays false, which stops an accidental rescan |
| `int_campaign_events_daily` | Incremental, partition replace | Same |
| `prep_teasers_cms` | Table | Small |
| `prep_online_placements_salesforce*` | Table | Small, and the sheet is edited in place |
| `int_campaign_context_daily` | Table | Must reflect every metadata fix |
| `dim_campaign` | Table | Small |
| `fact_campaign_performance_daily` | Table | Cheap, and must reflect every metadata fix |

**Why `insert_overwrite` and not `merge`:** events are append-only by day, so whole-day replacement is simple and always safe to rerun. With `copy_partitions: true` it uses BigQuery's copy API, with no `MERGE` at all.

**[Tested]** Two reruns kept totals exact. `--full-refresh` did not rescan.

## The 1 TB a day problem

| Lever | Effect |
|---|---|
| Partition by event day | Each run reads only its window |
| Select needed columns | BigQuery bills by columns read **[Documented]** |
| Filter to ad events in prep | Later steps never touch the rest of GA4 |
| Cluster on `campaign_type`, `campaign_ref` | Campaign filters read fewer blocks |
| Aggregate to day, campaign, device | Here 62x fewer rows |
| Dashboard reads only the marts | Analysts never touch events |

**In real GA4,** the export is nested. `prep_tracking_events` would use `UNNEST(event_params)` to pull fields. The supplied file is already flattened, so that step is not shown here.

### What breaks first at 10x

1. The nightly 3-day window grows linearly. Answer: clustering first, then slot reservations, then a filtered ad-events extract earlier in the chain.
2. `campaign_name` volume is not the issue, data quality is. The name join gets riskier as more names reuse. Answer: upstream fix number 1.
3. Airflow on one machine obviously does not scale. Production would use managed Airflow. This setup is only for the case study.

## GA4: how the data arrives, and late data

**[Documented]** from Google's Help Center. Google's wording varies slightly between pages, so check the current docs before quoting:

| Fact | Consequence |
|---|---|
| `events_YYYYMMDD` is the stable daily table | Build from this |
| `events_intraday_YYYYMMDD` is best effort, and deleted when the daily table is complete | Never build reporting on it |
| Daily tables can keep receiving events for up to about 3 days after the event date | Hence `lookback_days: 3` |
| Later events are dropped | So a window slightly over 72 hours is enough |
| `event_date` uses the property's timezone | Reporting date follows this |
| `event_timestamp` is UTC microseconds | Do not derive reporting dates from it without converting |
| Delivery time is not fixed | Use a sensor, not a fixed clock |
| GA4 has no event id | Hash the identifying fields |

**A tension with the brief:** it says this data "remains immutable" once loaded, while Google says daily tables can change for about 3 days. They can both be true if About You loads after the window closes, or copies the table once. Ask which it is. The design is correct in both cases: if events are truly immutable after loading, set `lookback_days` to 0 and save cost.

### Late-data contingency plan

| Scenario | Handling | Status |
|---|---|---|
| Event arrives within 3 days | Next run rebuilds that day | **[Tested]** +5 impressions, +2 clicks exactly |
| Same run repeated | Unchanged files are skipped, and rebuilt partitions replace old ones | **[Tested]** |
| Event arrives after the window | Not picked up automatically | **[Tested]** Then backfill below |
| Campaign metadata arrives after events | Fact rebuilds daily, row self-heals. Until then `outside_campaign_dates` | Design |
| New campaign appears in tracking first | `is_inferred` row in `dim_campaign` | Design |
| GA4 export is late | Sensor waits up to 12 hours | **[Tested]** the check reports not ready for a day without data, and ready for a day with data |
| Pipeline down for days | Backfill below | **[Tested]** via run_date |
| Logic change needs history | Backfill below, chunked by date | Design |

**Backfill command:**

```bash
cd dbt && ~/.venvs/dbt/bin/dbt run -s prep_tracking_events+ --vars '{run_date: "2025-06-08", lookback_days: 30}'
```

## Late events and conversions

**The scenario:** an impression and a conversion happen on Monday, but the click event only lands three days later, stamped Monday. With a one or two day lookback, Monday is never rebuilt, so the click is missed. A fixed window shorter than the lateness fails silently.

**How this design handles it today:**

- Reporting uses event time, not load time, so a late event lands on its true day.
- Each run rebuilds the last 3 days, which covers GA4's documented window.
- Rebuilding replaces whole partitions, so reruns cannot double count **[Tested]**.

**When conversion data is added.** It is not in the brief and is not built here, and no dummy data was added, because the requested KPIs do not need it. The rules would be:

1. The rebuild window equals the attribution window plus the late window. With a 7 day attribution window and 3 late days, each run rebuilds 10 days. These values are examples to agree with the business.
2. Recent days are marked provisional and become final only when the window closes.
3. Brand reports show final numbers, or label provisional ones.
4. Changed partitions older than the window are found from `INFORMATION_SCHEMA.PARTITIONS` and `last_modified_time`, and rebuilt on their own, instead of widening the window for everyone.

## Timezones, a real risk

Three different clocks exist:

| Source | Clock | Evidence |
|---|---|---|
| CMS | UTC | 785 starts are exactly midnight Berlin **[Tested]** |
| Salesforce | Plain dates, presumably Berlin | **[Assumption]** |
| Tracking file | Unclear | See below |

The tracking file spans exactly 00:00:00 to 23:59:59 on its two dates. A genuine UTC export of a Berlin-time property would be expected to run 22:00 to 21:59. So the file clock appears to equal the reporting day, and we take the date as written. **[Assumption]** Confirm with them.

## Airflow

**Three DAGs, each started by the one before:**

| DAG | Tasks | Why it is separate |
|---|---|---|
| `rtm_ingestion` | Load sources, wait for events, seed | Depends on outside systems |
| `rtm_dbt_models` | Prep, intermediate, marts | Models can be rebuilt without reloading sources |
| `rtm_dbt_tests` | Freshness, then all tests | A failed test is a clear signal, and tests can rerun alone |

Tests run after all models, so a failed test alerts the team but does not stop a table already built. A production setup could publish only after tests pass.

| Choice | Why |
|---|---|
| Local Airflow 2.11 | Free and open source |
| Separate virtualenvs for dbt and Airflow | Their dependencies conflict |
| BashOperator calling dbt | Simple. Cosmos would give per-model tasks, but is more than this needs |
| `max_active_runs=1` | Two runs replacing the same partition must not overlap |
| `mode="reschedule"` sensor | Frees the worker slot between checks |
| Copy sources runs even if GA4 is late | A missed CMS copy can never be recovered |

**A real problem we hit:** on macOS 27, anything Airflow forks can crash or hang. This affects the laptop setup only, not the design. Three fixes, each kept in the project with a comment:

| Symptom | Cause | Fix |
|---|---|---|
| Every worker crashed with `SIGSEGV` | `setproctitle` segfaults after `fork()`, reproduced in 4 lines | No-op replacement, in `orchestration/setup_airflow.sh` |
| Web workers still crashed | Forked gunicorn workers | Threaded web server, in `orchestration/start_airflow.sh` |
| Scheduled tasks hung at 100% CPU | Forked task process | `orchestration/runner/exec_task_runner.py` starts tasks as new processes |

The third only appeared on a real scheduler run, because `airflow dags test` does not fork. That is why the pipeline was tested both ways.

**Runs are triggered.** `rtm_ingestion` has no schedule locally. Production sets `RTM_SCHEDULE`. Identical files are skipped, so a repeated run adds no copy.

## The BigQuery sandbox

The development project has no billing account, so it is a sandbox. **[Tested]** limits:

| Limit | What happens | Our answer |
|---|---|---|
| Date partitions older than 60 days | **Rows vanish, with no error** | Integer partitions on `UNIX_DATE` |
| No `INSERT`, `UPDATE`, `DELETE`, `MERGE` | Query rejected | `copy_partitions`, load jobs |
| Tables expire after 60 days | Tables deleted around 30 December 2026 | Rerun `make load` and rebuild |
| dbt snapshots | Need `MERGE` | Daily raw copies |

Enabling billing on this one project would allow native `DATE` partitions: set `use_date_partitions: true`. That path is **[Not tested]**. Production would use native date partitions, which is a single switch.

## Deliberately not built

| Not built | Why not |
|---|---|
| Full SCD type 2 | Nothing requires point-in-time gender yet. Raw copies keep the option open |
| Bridge table for campaign lines | No dashboard filter needs line-level detail |
| Data mesh, streaming, Kafka | Daily reporting is the stated need |
| Elementary, Great Expectations | dbt tests cover the current risks |
| Allocating overlapping lines | Would invent numbers |
| A semantic layer | One dashboard. Revisit at three or more consumers |
| Full dashboard build | Not in the five deliverables |
