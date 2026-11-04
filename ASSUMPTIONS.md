# Assumptions and questions

What was assumed, and why. Each one should be confirmed with the Retail Media team.

| Assumption | Why |
|---|---|
| Gender means the campaign's target audience, not the viewer | Tracking has no gender, so it comes from campaign details |
| Both sources use the same seven gender labels once lowercased | Salesforce writes Female, UNISEX and Babys, and has 2 rows of "Women, Gen Z" from 2023 with reach 0 and no tracking. Prep lowercases and fixes Babys. A blank stays unknown |
| Placement events carry no campaign id | Every placement row has no id, and every teaser row has one, so placements match on name and date |
| Placements match bookings on name and date | Names are reused for years, so name alone overcounts |
| Teasers match the CMS on campaign id | The id is unique, while names repeat |
| Teasers sharing a name are separate campaigns | They have different ids, audiences and dates |
| An impression counts every occurrence | The brief defines impressions as total campaign views |
| Reach is the maximum number of impressions the platform promises to serve on a booked line | It is used only to weight the benchmark when two lines overlap, so a small line moves it less than a large one |
| Booked value is reach x CPM / 1000 | Not stored, because spend is not one of the requested metrics |
| A CPM of zero is unknown, not free | Nothing in the data confirms either |
| Benchmark applies evenly across a line's days and devices | The sheet has one value per booked line |
| Overlapping bookings stay one row, labelled mixed | Tracking cannot split them, and splitting would invent numbers |
| Conflicting booking versions are kept and flagged | A correction and a second booking look the same |
| Exact duplicate events are errors | They match on every field, down to the second |
| Clicks seen before their impression are kept | A click needs an impression first, so the impression is assumed to be logged late. CTR uses counts, not order |
| Events before a teaser's start date are kept | The CMS keeps only the current date, which may have been edited |
| Placement events outside every booked date range count as impressions and clicks, but never against a benchmark | The ad really showed, but no booking pays for it. They stay labelled outside_campaign_dates so they can be filtered out |
| Tracking dates are already the reporting day | The file runs exactly midnight to midnight |
| Session id is taken as it arrives | No requested metric uses sessions. Only the spare column unique_session_views does, until the team defines a session |
| Brand is an extra filter, not in the brief | No source has a brand column, so it is looked up from the campaign name in a fixed list (brand_list). Names not on the list get no_brand |
| Events are immutable once loaded | Stated in the brief |

## Questions for the Retail Media team

**Metrics**
- Is an impression a render or a viewable impression, and does it follow a standard such as MRC?
- Should repeat impressions count? One session can see a campaign up to 24 times, so is frequency capped?
- How is a session defined? Sessions in the sample last hours and overlap.

**Commercial**
- Is each campaign billed on impressions, clicks or conversions, and from which system?
- How is delivery paced against reach, and what happens when a line under-delivers?
- When a CPM changes, is it a correction for the whole line or a new price from that moment?
- Who sets benchmarks, and why do 45.5% of placement impressions have none?
- Does a CPM of zero mean free, bonus or missing?
- Why do 14 placements show events outside their booked dates? Are they running unpaid?

**Data**
- Why do some clicks come before the first impression? Are event times set by the device or the server?
- Are teaser start dates edited after launch, and do blank end dates mean open-ended?
- What do country codes 1 to 5 mean? Does a placement format exist?
- How much traffic is lost to cookie consent or ad blockers?
- Which timezone is reported to brands, and when does GA4 data count as final?

