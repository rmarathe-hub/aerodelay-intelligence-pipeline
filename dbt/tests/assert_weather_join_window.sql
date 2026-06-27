{% set window_hours = var('weather_join_window_hours') %}

-- Matched flights must have weather_valid_utc within the join window
select count(*) as window_violations
from {{ ref('int_flights__weather_at_departure') }}
where weather_match_status = 'matched'
  and (
    weather_valid_utc is null
    or weather_valid_utc < dep_time_utc - (interval '1 hour' * {{ window_hours }})
    or weather_valid_utc > dep_time_utc + (interval '1 hour' * {{ window_hours }})
  )
having count(*) > 0
