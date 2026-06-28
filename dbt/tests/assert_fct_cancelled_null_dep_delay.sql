-- Cancelled flights should keep null departure delay metrics
select count(*) as cancelled_with_dep_delay
from {{ ref('fct_flights') }}
where is_cancelled
  and dep_delay_minutes is not null
having count(*) > 0
