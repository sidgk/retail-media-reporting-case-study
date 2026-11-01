# Prep layer

Cleans each source and nothing more: deduplicate, typecast and basic tests. Column names match the source, plus `dwh_load_time`. There is no business logic and no joining of sources here. Logic belongs in intermediate and marts. Each model is named after its source file with a `prep_` prefix, and is built into the `rtm_prep` dataset.

| Model | In plain words | Reads | One row is | Built as |
|---|---|---|---|---|
| `prep_tracking_events` | What shoppers did: every ad impression and click | `rtm_raw.tracking_events` | One event | Incremental |
| `prep_teasers_cms` | Teasers set up in the shop, including ones the CMS later deleted | `rtm_raw.teasers_cms` | One teaser | Table |
| `prep_online_placements_salesforce` | What brands booked, with expected CTR and price | `rtm_raw.online_placements_salesforce` | One booked line | Table |
| `prep_online_placements_salesforce_rejected` | Sheet rows that have data but no campaign name, kept aside for review | `rtm_raw.online_placements_salesforce` | One rejected row | Table |

## What each model does

**`prep_tracking_events`** keeps the columns reporting needs, fixes types and removes exact duplicates. `event_id` exists only to find duplicates, because GA4 has no event id.

**`prep_teasers_cms`** fixes types and keeps each campaign's newest daily copy. That single step is the deduplication, and it also means a campaign deleted from the CMS stays here.

**`prep_online_placements_salesforce`** reads the newest copy of the sheet, parses `05.06.2025`, `30,000` and `0.28%` into real types, and removes exact duplicates. `placement_line_id` is added because the sheet has no id.

**`prep_online_placements_salesforce_rejected`** is the quarantine. Those rows can't be linked to any tracking event, because the campaign name is the only link. They're saved here so the team can fix them. Blank rows at the bottom of the sheet are ignored.

## Deleted campaigns

The CMS removes deactivated campaigns every day, and it has no soft delete. So raw keeps a full daily copy, and `prep_teasers_cms` keeps each campaign's newest copy. A deleted campaign therefore stays here, with its gender and dates, and old events never lose their details. To list deleted campaigns, compare the daily copies in `rtm_raw.teasers_cms`: a campaign in an older copy but missing from the newest has been removed. Today raw holds one copy, so none can be seen yet.

Each model's columns and tests are in the `.yml` file with the same name.
