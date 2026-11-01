# Assumptions

What was assumed, and why. Each one should be confirmed with the Retail Media team.

| Assumption | Why |
|---|---|
| Gender means the campaign's target audience, not the viewer | Tracking has no gender, so it comes from campaign details |
| Placements arrive in tracking with no campaign id by design | Every placement row has no id, and every teaser row has one |
| Placements match bookings on name and date | Names are reused for years, so name alone overcounts |
| Teasers match the CMS on campaign id | The id is unique, while names repeat |
| Teasers sharing a name are separate campaigns | They have different ids, audiences and dates |
| An impression counts every occurrence | The brief defines impressions as total campaign views |
| Reach means booked impressions | Not defined in the brief, and CPM falls as reach rises |
| Spend is reach x CPM / 1000 | Standard CPM meaning. Not stored, because it rests on the line above |
| A CPM of zero is unknown, not free | Nothing in the data confirms either |
| Benchmark applies evenly across a line's days and devices | The sheet has one value per booked line |
| Overlapping bookings stay one row, labelled mixed | Tracking cannot split them, and splitting would invent numbers |
| Conflicting booking versions are kept and flagged | A correction and a second booking look the same |
| Exact duplicate events are errors | They match on every field, down to the second |
| Clicks seen before their impression are kept | A click needs an impression first, so the impression is assumed late or lost. A 3-day lookback allows for late events, and CTR uses counts, not order |
| Events before a teaser's start date are kept | The CMS keeps only the current date, which may have been edited |
| Tracking dates are already the reporting day | The file runs exactly midnight to midnight |
| A session follows GA4's default of 30 minutes of inactivity | Sessions in the sample overlap and last hours, so the data cannot define them |
| Brand is the first word of the campaign name | No source has a brand column |
| CK and Calvin are separate brands | Nothing proves they are one |
| Events are immutable once loaded | Stated in the brief |
