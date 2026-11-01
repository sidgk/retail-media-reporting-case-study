{{ config(severity='warn', warn_if='>0') }}

-- The same booking appears with different numbers. It may be a correction or two real lines, and
-- only the Retail Media team can say which.

select campaign_name, campaign_start, campaign_end, gender, country_cluster, count(*) as versions
from {{ ref('prep_online_placements_salesforce') }}
group by 1, 2, 3, 4, 5
having count(*) > 1
