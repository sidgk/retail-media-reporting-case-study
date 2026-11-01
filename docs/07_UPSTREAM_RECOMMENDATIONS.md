# Upstream recommendations

Ranked by value. Effort levels are estimates to confirm with each owner.

| # | Change | Owner | Effort | Benefit |
|---|---|---|---|---|
| 1 | Send a Salesforce line id into tracking | Retail Media, frontend | Medium | Removes the name join, and with it the 5.7x risk |
| 2 | CMS soft deletes, keeping status and date | CMS team | Low | Keeps history at the source |
| 3 | Replace the manual sheet with a Salesforce sync or validated form | Retail Media, sales operations | Medium | Ends format and duplicate problems |
| 4 | Required fields and dropdowns at campaign setup | Retail Media, CMS team | Low | Stops gaps at entry |
| 5 | Add placement format to each booking | Retail Media | Low | Explains each benchmark |
| 6 | Add a brand id to every campaign | Retail Media | Low | Replaces deriving brand from the name |
| 7 | Agree one written impression definition | Retail Media, tracking | Low | Stops CTR meaning two things |
| 8 | Add gender, country and page type to tracking | Tracking owner | Medium | Allows true audience and placement reporting |

Number 1 removes most of the complexity in this project.

## Data collection

- Record an event id in tracking, so deduplication stops relying on a hash.
- Confirm how much traffic is lost to cookie consent.
- Agree whether brands are billed on GA4, an ad server or the booking.
