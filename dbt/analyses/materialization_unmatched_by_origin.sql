-- Unmatched flights by origin (station mapping / sparse obs diagnosis).
select
    origin,
    weather_match_status,
    count(*) as flights
from {{ ref('int_flights__weather_at_departure') }}
where weather_match_status = 'no_obs_in_window'
group by origin, weather_match_status
order by flights desc
