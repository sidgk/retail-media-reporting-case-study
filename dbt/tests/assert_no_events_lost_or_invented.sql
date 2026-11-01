-- The most important test in the project. The fact must equal the event table, day by day, for impressions and
-- clicks. A join that fans out or drops rows fails here even if every other test passes.

with events as (

    select event_date,
           countif(event_type = 'impression') as impressions,
           countif(event_type = 'click')      as clicks
    from {{ ref('prep_tracking_events') }}
    group by 1

),

fact as (

    select event_date, sum(impressions) as impressions, sum(clicks) as clicks
    from {{ ref('fact_campaign_performance_daily') }}
    group by 1

)

select
    coalesce(events.event_date, fact.event_date) as event_date,
    events.impressions  as events_impressions,
    fact.impressions    as fact_impressions,
    events.clicks       as events_clicks,
    fact.clicks         as fact_clicks
from events
full outer join fact on events.event_date = fact.event_date
where events.impressions is distinct from fact.impressions
   or events.clicks is distinct from fact.clicks
