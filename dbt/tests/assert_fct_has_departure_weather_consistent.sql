-- has_departure_weather must align with weather_match_status
select count(*) as weather_flag_mismatch
from {{ ref('fct_flights') }}
where has_departure_weather <> (weather_match_status = 'matched')
having count(*) > 0
