{{ config(severity='warn', warn_if='>0') }}

-- A warning, not a failure: when more than 5% of a day's impressions match no booking, someone
-- should look at the sheet or the CMS. The numbers are still right, only the labels are incomplete.

select
    event_date,
    sum(impressions) as total_impressions,
    sum(if(match_status in ('outside_campaign_dates', 'not_in_source'), impressions, 0)) as unmatched_impressions
from {{ ref('fact_campaign_performance_daily') }}
group by 1
having safe_divide(unmatched_impressions, total_impressions) > 0.05
