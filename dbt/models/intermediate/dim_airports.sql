with airports as (
    select * from {{ ref('airports_45') }}
),

stations as (
    select
        airport_code,
        weather_station_id,
        station_source
    from {{ ref('airport_station_map') }}
),

timezones as (
    select * from {{ ref('airport_timezones') }}
)

select
    a.airport_code,
    a.airport_name,
    a.city,
    a.state,
    a.region,
    tz.timezone,
    s.weather_station_id,
    s.station_source
from airports as a
inner join timezones as tz on a.airport_code = tz.airport_code
inner join stations as s on a.airport_code = s.airport_code
