# Assumptions and questions

What was assumed, and why. Each one should be confirmed with the Retail Media team.

| Assumption | Why |
|---|---|
| Gender means the campaign's target audience, not the viewer | Tracking has no gender, so it comes from campaign details |
| Placements arrive in tracking with no campaign id by design | Every placement row has no id, and every teaser row has one |
| Placements match bookings on name and date | Names are reused for years, so name alone overcounts |
| Teasers match the CMS on campaign id | The id is unique, while names repeat |
| Teasers sharing a name are separate campaigns | They have different ids, audiences and dates |
| An impression counts every occurrence | The brief defines impressions as total campaign views |
| Reach means booked impressions | Not defined in the brief. Median CPM falls from 51 below 100k reach to 5 above 1m, and reach x benchmark CTR matches benchmark clicks on about 2 in 3 lines. This supports it but does not prove it |
| Booked value is reach x CPM / 1000 | CPM is the price per 1,000 impressions, so this holds only if reach means impressions. Not stored, because it rests on the line above |
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
| CK and Calvin are the same brand, Calvin Klein | CK is the standard short form in fashion |
| Events are immutable once loaded | Stated in the brief |

## Questions for the Retail Media team

**Metrics**
- Is an impression a render or a viewable impression, and does it follow a standard such as MRC?
- Should repeat impressions count? One session can see a campaign up to 24 times, so is frequency capped?
- How is a session defined, and has the 30-minute GA4 default been changed?

**Commercial**
- Is each campaign billed on impressions, clicks or conversions, and from which system?
- What does reach mean, and how is delivery paced against it?
- Who sets benchmarks, and why do 45.5% of placement impressions have none?
- Does a CPM of zero mean free, bonus or missing?
- Why do 14 placements show events outside their booked dates? Are they running unpaid?

**Data**
- Why do some clicks come before the first impression?
- Are teaser start dates edited after launch, and do blank end dates mean open-ended?
- What do country codes 1 to 5 mean? Does a placement format exist?
- How much traffic is lost to cookie consent or ad blockers?
- Which timezone is reported to brands, and when does GA4 data count as final?

