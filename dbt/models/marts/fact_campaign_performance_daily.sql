{{ config(
    partition_by=day_partition(),
    cluster_by=['campaign_type', 'campaign_key'],
    contract={'enforced': true}
) }}

-- Grain: one row per day, campaign and device. What the dashboard reads.
-- A full rebuild on purpose: it reads daily aggregates, so it is cheap, and it picks up every sheet
-- or CMS correction across all of history. Store counts, not rates: rates cannot be summed.

select
    events.event_day,
    events.event_date,
    events.campaign_key,
    events.campaign_type,
    events.campaign_ref,
    events.campaign_name,
    campaigns.brand,
    events.device,
    context.target_gender,
    context.match_status,
    context.booked_lines,
    context.benchmark_ctr,
    events.impressions,
    events.clicks,
    events.unique_session_views,
    -- These two make the benchmark safe to roll up over any filter: sum and divide, never average.
    if(context.benchmark_ctr is null, 0, events.impressions)        as impressions_with_benchmark,
    events.impressions * coalesce(context.benchmark_ctr, 0)         as expected_clicks
from {{ ref('int_campaign_events_daily') }} as events
left join {{ ref('int_campaign_context_daily') }} as context
    on events.campaign_key = context.campaign_key
    and events.event_date = context.event_date
left join {{ ref('dim_campaign') }} as campaigns
    on events.campaign_key = campaigns.campaign_key
