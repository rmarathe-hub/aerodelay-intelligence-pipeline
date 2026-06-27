-- Cancelled flights should have null departure delay metrics
select count(*) as cancelled_with_dep_delay
from {{ ref('int_flights__departure_context') }}
where is_cancelled
  and dep_delay_minutes is not null
having count(*) > 0
