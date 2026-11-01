-- Quarantine. Rows with data but no campaign name cannot be used, and must not vanish silently.
-- Fully blank rows are the sheet's empty bottom rows and are not worth keeping.

with source as (

    select * from {{ source('raw', 'online_placements_salesforce') }}
    qualify _snapshot_day = max(_snapshot_day) over ()

)

select
    'missing_campaign_name' as rejection_reason,
    campaign_start,
    campaign_end,
    gender,
    country_cluster,
    reach,
    currency_cpm,
    cpm,
    benchmark_ctr,
    benchmark_clicks,
    current_timestamp() as dwh_load_time
from source
where campaign_name is null
  and coalesce(campaign_start, campaign_end, gender, country_cluster, reach, currency_cpm, cpm,
               benchmark_ctr, benchmark_clicks) is not null
