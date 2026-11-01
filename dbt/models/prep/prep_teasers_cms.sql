-- One row per teaser, typed. Raw holds one full copy of the CMS per day, so deduplicating means
-- keeping each campaign's newest copy. That also keeps campaigns the CMS has since deleted.

select
    campaign_id,
    trim(campaign_name)                     as campaign_name,
    lower(trim(gender))                     as gender,
    safe_cast(active_from as timestamp)     as active_from,
    safe_cast(active_to as timestamp)       as active_to,
    current_timestamp()                     as dwh_load_time
from {{ source('raw', 'teasers_cms') }}
qualify row_number() over (partition by campaign_id order by _snapshot_date desc) = 1
