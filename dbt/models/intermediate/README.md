# Intermediate layer

Shared business logic between prep and marts. A model exists here only when it earns its place. Built into the `rtm_int` dataset.

| Model | In plain words | Reads | One row is | Built as |
|---|---|---|---|---|
| `int_campaign_events_daily` | Events turned into daily counts | `prep_tracking_events` | One date, campaign and device | Incremental |
| `int_campaign_context_daily` | Each campaign's audience, benchmark and booking match, per day | `int_campaign_events_daily`, `prep_teasers_cms`, `prep_online_placements_salesforce` | One date and campaign | Table |

## Why there are two

**`int_campaign_events_daily` holds the expensive work.** Events never change, so this table is built incrementally. It creates `campaign_ref` and `campaign_key`, the campaign's identity across the project. It has no gender or benchmark, on purpose: fixing the sheet must not force a rescan of events.

**`int_campaign_context_daily` holds the logic that can change.** This is where the three sources connect:

- Teasers match the CMS on `campaign_id`.
- Placements match Salesforce on name, with the date inside the campaign dates, because names are reused for years.

| `match_status` | Meaning |
|---|---|
| `matched` | Exactly one booking covers this day |
| `matched_multiple_lines` | Several bookings overlap. Gender becomes `mixed` and the benchmark is weighted by reach |
| `outside_campaign_dates` | Seen on a day no booking covers |
| `not_in_source` | Teaser id missing from the CMS |

**To add a campaign type:** add one more CTE to `int_campaign_context_daily` with the same columns, then one more `union all` branch.

Each model's columns and tests are in the `.yml` file with the same name.
