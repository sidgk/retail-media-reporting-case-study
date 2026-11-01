{{ config(severity='warn', warn_if='>0', tags=['prep', 'daily']) }}

-- Catches a half-finished sheet export or a CMS outage: a snapshot more than 20% smaller than the
-- one before it.

with snapshots as (

    select 'teasers_cms' as source_table, _snapshot_date, count(*) as row_count
    from {{ source('raw', 'teasers_cms') }}
    group by 2

    union all

    select 'online_placements_salesforce', _snapshot_date, countif(campaign_name is not null)
    from {{ source('raw', 'online_placements_salesforce') }}
    group by 2

),

compared as (

    select *, lag(row_count) over (partition by source_table order by _snapshot_date) as previous_row_count
    from snapshots

)

select * from compared
where row_count < previous_row_count * 0.8
