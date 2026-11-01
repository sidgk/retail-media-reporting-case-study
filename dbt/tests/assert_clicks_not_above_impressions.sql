-- A day and campaign with more clicks than impressions means broken tracking.

select event_date, campaign_key, sum(impressions) as total_impressions, sum(clicks) as total_clicks
from {{ ref('fact_campaign_performance_daily') }}
group by 1, 2
having total_clicks > total_impressions
