# Data governance and monitoring

**The rule:** fail when numbers would be wrong. Warn when numbers are right but labels are incomplete. Noisy alerts get ignored.

## Checks and owners

| Risk | Check | Severity | Owner |
|---|---|---|---|
| Rows lost or invented | Fact equals event table, per day | Fail | Analytics engineering |
| A join fans out | Unique grain tests | Fail | Analytics engineering |
| Schema changes | Strict load, enforced contract on the fact | Fail | Analytics engineering |
| New gender label | Accepted values test | Fail | Analytics engineering |
| Sheet date or number format changes | Not-null tests after safe parsing | Fail | Retail Media team |
| Half-finished sheet export | Row count down over 20% | Warn | Retail Media team |
| Over 5% of impressions unmatched | Daily share | Warn | Retail Media team |
| Conflicting booking versions | Duplicate booking key | Warn | Retail Media team |
| Rows without a name | Quarantine table | Regular review | Retail Media team |
| Late data | Source freshness over 26 hours | Warn | Analytics engineering |

Coverage: 32 data tests and 3 unit tests, each guarding a real failure. Failed rows are stored in `rtm_audit`, so someone can act on them. Two deliberate logic breaks were caught when tested.

## Manual sources: side effects and controls

| What can go wrong | Effect | Control |
|---|---|---|
| A row or campaign is edited after launch | History changes silently | Daily full copy in raw, so any date can be replayed |
| The sheet is half-saved or emptied | Campaigns disappear | Row count warning, and the previous copy remains |
| Date or number format changes | Bad joins | Explicit schema, strict load, safe parsing, not-null tests |
| A new spelling of a label | Dashboard filter splits | Accepted values test |
| Campaign name is missing or mistyped | Events cannot be matched | Quarantine table and unmatched share warning |
| Same booking entered twice | Double counting of booked value | Exact duplicates removed, conflicts flagged |
| CMS deletes a campaign | Old events lose gender and dates | Daily copy keeps the last known version |
| Sheet is updated late | Temporary mismatch | Fact rebuilds daily, so rows heal by themselves |

## Operating model

- **Ownership:** every source and mart has a named owner, and every alert goes to one owner.
- **Run order:** load sources, build models, then test everything.
- **Change control:** the fact has an enforced contract, so a changed column stops the build.
- **Documentation:** each model has its own YAML with columns and tests, and descriptions are written into BigQuery.
- **Privacy:** `visitor_id` is a device identifier. Marts hold no visitor or session ids, only aggregates.

## Not built, needed for production

Failure alerts to a team channel, a dashboard of pipeline health, and agreed delivery times. These depend on About You's tooling.
