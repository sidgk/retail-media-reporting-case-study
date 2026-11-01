-- For each campaign on each day it was seen: its audience, benchmark and how well it matched a booking.
-- To add a campaign type, add one more CTE with these same columns and one more union branch.

with campaign_days as (

    select distinct event_date, campaign_key, campaign_type, campaign_ref
    from {{ ref('int_campaign_events_daily') }}

),

teasers as (

    select
        days.event_date,
        days.campaign_key,
        coalesce(cms.gender, 'unknown')             as target_gender,
        cast(null as numeric)                       as benchmark_ctr,
        if(cms.campaign_id is null, 0, 1)           as booked_lines,
        case
            when cms.campaign_id is null then 'not_in_source'
            -- The CMS stores UTC, and 785 of 965 starts are exactly midnight in Berlin.
            when days.event_date < date(cms.active_from, '{{ var("reporting_timezone") }}') then 'outside_campaign_dates'
            when days.event_date > date(cms.active_to, '{{ var("reporting_timezone") }}') then 'outside_campaign_dates'
            else 'matched'
        end                                         as match_status
    from campaign_days as days
    left join {{ ref('prep_teasers_cms') }} as cms
        on days.campaign_ref = cms.campaign_id
    where days.campaign_type = 'teaser'

),

placement_lines as (

    -- Name alone is not enough: names are reused for years. The event date must fall inside the campaign dates.
    select
        days.event_date,
        days.campaign_key,
        lines.placement_line_id,
        coalesce(lines.gender, 'unknown')           as gender,
        lines.reach,
        lines.benchmark_ctr
    from campaign_days as days
    left join {{ ref('prep_online_placements_salesforce') }} as lines
        on days.campaign_ref = lines.campaign_name
        and days.event_date between lines.campaign_start and lines.campaign_end
    where days.campaign_type = 'online_placement'

),

placements as (

    select
        event_date,
        campaign_key,
        -- Tracking has no gender or country, so events cannot be split across lines. Say so rather
        -- than invent an allocation.
        case
            when count(placement_line_id) = 0 then 'unknown'
            when count(distinct gender) > 1 then 'mixed'
            else any_value(gender)
        end                                         as target_gender,
        -- Weighted by reach, so a small line cannot move the benchmark as much as a large one.
        coalesce(
            safe_divide(sum(if(benchmark_ctr is not null, benchmark_ctr * reach, 0)),
                        sum(if(benchmark_ctr is not null, reach, 0))),
            avg(benchmark_ctr)
        )                                           as benchmark_ctr,
        count(placement_line_id)                    as booked_lines,
        case
            when count(placement_line_id) = 0 then 'outside_campaign_dates'
            when count(placement_line_id) = 1 then 'matched'
            else 'matched_multiple_lines'
        end                                         as match_status
    from placement_lines
    group by 1, 2

)

select * from teasers
union all
select * from placements
