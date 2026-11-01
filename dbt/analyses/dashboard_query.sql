-- What the dashboard runs. All four filters, and every rate computed after summing.
select
    campaign_name,
    sum(impressions)                                                as impressions,
    sum(clicks)                                                     as clicks,
    safe_divide(sum(clicks), sum(impressions))                      as ctr,
    safe_divide(sum(expected_clicks), sum(impressions_with_benchmark)) as benchmark_ctr,
    safe_divide(sum(impressions_with_benchmark), sum(impressions))  as benchmark_coverage
from {{ ref('fact_campaign_performance_daily') }}
where event_date between '2025-06-07' and '2025-06-08'
  -- and campaign_name = 'Gap Fall Premium Flash'
  -- and device = 'mobile'
  -- and target_gender = 'female'
group by 1
order by impressions desc
