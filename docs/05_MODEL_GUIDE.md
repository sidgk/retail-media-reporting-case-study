# How each model works

Build order, expected results and the logic of each model. To rebuild and test one model, run this from the `dbt` folder with the environment active:

```bash
dbt build --select prep_teasers_cms
```

## Expected results

| Order | Model | Expected rows |
|---:|---|---:|
| 1 | `prep_teasers_cms` | 965 |
| 2 | `prep_online_placements_salesforce` | 24,761 |
| 3 | `prep_online_placements_salesforce_rejected` | 219 |
| 4 | `prep_tracking_events` | 308,576 |
| 5 | `int_campaign_events_daily` | 4,968 |
| 6 | `int_campaign_context_daily` | 2,484 |
| 7 | `dim_campaign` | 19,643 |
| 8 | `fact_campaign_performance_daily` | 4,968 |

Seed: `brand_list`.

**Final check:** the fact totals **300,084 impressions** and **8,492 clicks**. Teaser impressions `outside_campaign_dates` are 2,222, placement impressions `outside_campaign_dates` are 3,296, and `matched_multiple_lines` are 2,766.

## Model specs

### 1. `prep_teasers_cms`

- **Read:** `source('raw', 'teasers_cms')`
- **Grain:** one row per `campaign_id`
- **Steps:** one select. Trim the name, lowercase gender, `safe_cast` both dates to TIMESTAMP, and keep each campaign's newest copy with `qualify row_number()`.

### 2. `prep_online_placements_salesforce`

- **Read:** the newest snapshot only, where `campaign_name` is not null
- **Grain:** one row per booked line
- **Steps:**
  1. `safe.parse_date('%d.%m.%Y', ...)` for both dates.
  2. Remove commas from reach and cast to INT64.
  3. Remove `%` from `benchmark_ctr`, cast to NUMERIC, divide by 100.
  4. Lowercase gender and correct `babys` to `babies`.
  5. `select distinct` to remove exact copies.
  6. Add `placement_line_id` with `dbt_utils.generate_surrogate_key`.
- **Traps:** use `safe.` functions, so bad values become nulls that tests catch. Keep rate as a fraction: 0.28% is 0.0028.

### 3. `prep_online_placements_salesforce_rejected`

- **Read:** the newest snapshot, where `campaign_name` is null and at least one other column has a value
- **Add:** `rejection_reason = 'missing_campaign_name'`
- **Trap:** without the "one other column" rule, this returns 13,976 rows, including the sheet's 13,757 blank rows.

### 4. `prep_tracking_events`

- **Read:** `source('raw', 'tracking_events')` with `where {{ event_window('event_day') }}`
- **Grain:** one row per event
- **Steps:**
  1. Parse with `safe.parse_datetime('%F %T', event_timestamp)`.
  2. Lowercase `device`, `event_type`, `campaign_type`.
  3. Add `event_id` from all identifying fields, then keep one per `event_id`.
- **Trap:** keep `event_day`, because the table partitions on it. Do not read the source without the window macro.

### 5. `int_campaign_events_daily`

- **Read:** `ref('prep_tracking_events')` with the same window macro
- **Grain:** day, campaign, device
- **Output:** `campaign_ref`, `campaign_key`, `impressions`, `clicks`, `unique_session_views`
- **Keys:** `campaign_ref = coalesce(campaign_id, campaign_name)`, and `campaign_key` hashes `campaign_type` and `campaign_ref`.
- **Trap:** use `countif`, and `count(distinct if(...))` for sessions. No campaign details here beyond the name. That separation is the design.

### 6. `int_campaign_context_daily`

The core model of the project.

- **Read:** the three models above
- **Grain:** day, campaign
- **Output columns:** `event_date`, `campaign_key`, `target_gender`, `benchmark_ctr`, `booked_lines`, `match_status`
- **Steps:**
  1. Start from distinct campaign days in `int_campaign_events_daily`.
  2. **Teasers:** left join the CMS on `campaign_ref = campaign_id`. Status is `outside_campaign_dates` when the date is outside the active dates, and `not_in_source` when no match.
  3. **Placements:** left join on name **and** `event_date between campaign_start and campaign_end`.
  4. Group placements by date and campaign:
     - no lines: `unknown`, `outside_campaign_dates`
     - more than one distinct gender: `mixed`
     - benchmark: reach-weighted, falling back to the simple average when reach is 0
     - lines: 0 is `outside_campaign_dates`, 1 is `matched`, more is `matched_multiple_lines`
  5. `union all` the two.
- **Trap:** a blank gender counts as `unknown`, so treat it as its own value when counting genders.

### 7. `dim_campaign`

- **Grain:** one row per campaign
- **Steps:**
  1. Teasers from the CMS, one row each.
  2. Placements grouped by name, with earliest start and latest end.
  3. `union all`.
  4. Add any campaign seen in events but missing here, with `is_inferred = true`.
  5. Add `brand` from the first word of the name, using `seeds/brand_list.csv`, otherwise `no_brand`.
  6. Work out Berlin dates and `is_open_ended`.
- **Trap:** `campaign_key` must be built the same way as in tracking. Pass the literal type: `generate_surrogate_key(["'teaser'", 'campaign_id'])`.

### 8. `fact_campaign_performance_daily`

- **Grain:** day, campaign, device
- **Steps:** left join events to context on `campaign_key` and `event_date`, and add:
  - `impressions_with_benchmark = if(benchmark_ctr is null, 0, impressions)`
  - `expected_clicks = impressions * coalesce(benchmark_ctr, 0)`
- **Trap:** the contract in `fact_campaign_performance_daily.yml` is enforced. The columns and types must match it exactly, or the build refuses.

Then run `make test`. `assert_no_events_lost_or_invented` is the test that matters most.

## Running the whole pipeline in Airflow

The Airflow login uses `admin`, with the password stored in `orchestration/airflow_home/standalone_admin_password.txt`.

```bash
make airflow
```

Open http://localhost:8080, then unpause `retail_media_daily` and trigger it for a date with data:

```bash
source orchestration/env.sh && airflow dags trigger retail_media_daily -e 2025-06-08
```

Pause the DAG again afterwards. Trigger with `-e` a date already used fails, because a run for that date exists.
