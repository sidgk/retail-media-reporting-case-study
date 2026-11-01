{{ config(
    materialized='incremental',
    incremental_strategy='insert_overwrite',
    partition_by=day_partition(),
    cluster_by=['campaign_type', 'campaign_id'],
    on_schema_change='fail',
    full_refresh=var('allow_full_refresh')
) }}

{#- Ad events only, with only the columns reporting needs. In production this is the step that
    turns >1TB a day of GA4 into something cheap to reuse. full_refresh is off by default, so a
    stray --full-refresh cannot rescan history; backfills go through run_date instead. -#}

with typed as (

    select
        event_day,
        date(safe.parse_datetime('%F %T', event_timestamp))     as event_date,
        safe.parse_datetime('%F %T', event_timestamp)           as event_timestamp,
        session_id,
        visitor_id,
        lower(trim(device))                                     as device,
        lower(trim(event_type))                                 as event_type,
        lower(trim(campaign_type))                              as campaign_type,
        campaign_id,
        trim(campaign_name)                                     as campaign_name,
        _loaded_at
    from {{ source('raw', 'tracking_events') }}
    where {{ event_window('event_day') }}

),

keyed as (

    select
        *,
        -- GA4 has no event id, so an event is identified by everything we know about it.
        {{ dbt_utils.generate_surrogate_key(['session_id', 'visitor_id', 'device', 'event_timestamp', 'event_type', 'campaign_type', 'campaign_id', 'campaign_name']) }} as event_id
    from typed

)

select
    * except (_loaded_at),
    current_timestamp() as dwh_load_time
from keyed
qualify row_number() over (partition by event_id order by _loaded_at desc) = 1
