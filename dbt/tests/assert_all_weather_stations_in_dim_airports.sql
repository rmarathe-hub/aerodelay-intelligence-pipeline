-- Fail if any loaded weather station is missing from dim_airports
select distinct w.station as weather_station_id
from {{ ref('stg_weather__observations') }} as w
left join {{ ref('dim_airports') }} as a on w.station = a.weather_station_id
where a.weather_station_id is null
