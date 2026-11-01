-- One row per booked line, typed. Reads only the newest copy of the sheet, because it is edited in
-- place, and older copies stay in rtm_raw. Exact duplicates are removed.

with source as (

    select * from {{ source('raw', 'online_placements_salesforce') }}
    qualify _snapshot_day = max(_snapshot_day) over ()

),

typed as (

    select distinct
        trim(campaign_name)                                             as campaign_name,
        safe.parse_date('%d.%m.%Y', campaign_start)                     as campaign_start,
        safe.parse_date('%d.%m.%Y', campaign_end)                       as campaign_end,
        -- Babys is the one misspelling. Lowercasing fixes every other label.
        replace(lower(trim(gender)), 'babys', 'babies')                 as gender,
        trim(country_cluster)                                           as country_cluster,
        safe_cast(replace(reach, ',', '') as int64)                     as reach,
        currency_cpm,
        safe_cast(cpm as numeric)                                       as cpm,
        safe_divide(safe_cast(replace(benchmark_ctr, '%', '') as numeric), 100) as benchmark_ctr,
        safe_cast(replace(benchmark_clicks, ',', '') as int64)          as benchmark_clicks
    from source
    where campaign_name is not null

)

select
    {{ dbt_utils.generate_surrogate_key(['campaign_name', 'campaign_start', 'campaign_end', 'gender', 'country_cluster', 'reach', 'cpm', 'benchmark_ctr', 'benchmark_clicks']) }} as placement_line_id,
    *,
    current_timestamp() as dwh_load_time
from typed
