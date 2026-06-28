-- Cancelled or diverted flights must not be analysis-eligible
select count(*) as ineligible_flagged_wrong
from {{ ref('fct_flights') }}
where (is_cancelled or is_diverted)
  and is_analysis_eligible
having count(*) > 0
