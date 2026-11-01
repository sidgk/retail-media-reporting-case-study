# Marts layer

What people and dashboards query. Built into the `rtm_marts` dataset.

| Model | In plain words | Reads | One row is | Built as |
|---|---|---|---|---|
| `dim_campaign` | The master list of campaigns across all sources | `prep_teasers_cms`, `prep_online_placements_salesforce`, `int_campaign_events_daily`, `brand_list` | One campaign | Table |
| `fact_campaign_performance_daily` | Impressions, clicks and benchmark inputs for the dashboard | `int_campaign_events_daily`, `int_campaign_context_daily`, `dim_campaign` | One date, campaign and device | Table |

## `dim_campaign`

One row per campaign, whether it came from the CMS or Salesforce. A campaign seen in tracking but unknown to any source is added with `is_inferred = true`, so it's never lost. It lists every known campaign, including ones with no events in this window.

`brand` is derived from the campaign name, because no source has a brand column. Campaign dates in Berlin time and `is_open_ended` are also worked out here.

## `fact_campaign_performance_daily`

Stores counts, never rates. Use it like this for any filter:

| KPI | Formula |
|---|---|
| Impressions | `sum(impressions)` |
| CTR | `sum(clicks) / sum(impressions)` |
| Benchmark CTR | `sum(expected_clicks) / sum(impressions_with_benchmark)` |

Never average a CTR. `dbt/analyses/dashboard_query.sql` shows the full query.

**Why `target_gender` is on the fact:** for placements it can change by day as bookings start and stop. It describes the campaign's audience, not the viewer.

Each model's columns and tests are in the `.yml` file with the same name.
