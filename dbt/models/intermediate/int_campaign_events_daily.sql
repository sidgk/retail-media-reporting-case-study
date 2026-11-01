{{ config(
    materialized='incremental',
    incremental_strategy='insert_overwrite',
    partition_by=day_partition(),
    cluster_by=['campaign_type', 'campaign_ref'],
    on_schema_change='fail',
    full_refresh=var('allow_full_refresh')
) }}

{#- The expensive step, kept apart from campaign details on purpose. Fixing the Salesforce sheet
    or the CMS never touches this table, so a metadata correction never rescans events. -#}

with events as (

    select
        *,
        -- Teasers are identified by id. Placements have no id in tracking, so the name is all we have.
        coalesce(campaign_id, campaign_name) as campaign_ref
    from {{ ref('prep_tracking_events') }}
    where {{ event_window('event_day') }}

)

select
    event_day,
    event_date,
    {{ dbt_utils.generate_surrogate_key(['campaign_type', 'campaign_ref']) }} as campaign_key,
    campaign_type,
    campaign_ref,
    campaign_name,
    device,
    countif(event_type = 'impression')                              as impressions,
    countif(event_type = 'click')                                   as clicks,
    -- Stored until "impression" is defined. A session sits on one device and day, so this still sums.
    count(distinct if(event_type = 'impression', session_id, null)) as unique_session_views
from events
group by 1, 2, 3, 4, 5, 6, 7
