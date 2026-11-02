-- One row per campaign across every source. This shape is the contract each new source must meet.

with teasers as (

    select
        {{ dbt_utils.generate_surrogate_key(["'teaser'", 'campaign_id']) }} as campaign_key,
        'teaser'                as campaign_type,
        'cms'                   as source_system,
        campaign_id             as source_campaign_id,
        campaign_name,
        date(active_from, '{{ var("reporting_timezone") }}') as first_active_date,
        date(active_to, '{{ var("reporting_timezone") }}')   as last_active_date,
        active_to is null   as is_open_ended,
        false                   as is_inferred
    from {{ ref('prep_teasers_cms') }}

),

placements as (

    select
        {{ dbt_utils.generate_surrogate_key(["'online_placement'", 'campaign_name']) }} as campaign_key,
        'online_placement'      as campaign_type,
        'salesforce'            as source_system,
        cast(null as string)    as source_campaign_id,
        campaign_name,
        min(campaign_start)  as first_active_date,
        max(campaign_end)    as last_active_date,
        false                   as is_open_ended,
        false                   as is_inferred
    from {{ ref('prep_online_placements_salesforce') }}
    group by campaign_name

),

known as (

    select * from teasers
    union all
    select * from placements

),

-- Late-arriving campaign: events exist but the sheet or CMS has not caught up. Keep them visible.
inferred as (

    select distinct
        events.campaign_key,
        events.campaign_type,
        'tracking'              as source_system,
        if(events.campaign_type = 'teaser', events.campaign_ref, null) as source_campaign_id,
        events.campaign_name,
        cast(null as date)      as first_active_date,
        cast(null as date)      as last_active_date,
        false                   as is_open_ended,
        true                    as is_inferred
    from {{ ref('int_campaign_events_daily') }} as events
    left join known using (campaign_key)
    where known.campaign_key is null

),

all_campaigns as (

    select * from known
    union all
    select * from inferred

)

select
    all_campaigns.*,
    -- There is no brand column in any source, so it comes from the first word of the name, mapped
    -- through a fixed list, so CK and Calvin are both Calvin Klein. Season-only names such as "Fall Launch" have no brand, and must not get one.
    coalesce(brands.brand, 'no_brand') as brand
from all_campaigns
left join {{ ref('brand_list') }} as brands
    on split(all_campaigns.campaign_name, ' ')[safe_offset(0)] = brands.first_word
