with flights as (
    select * from {{ ref('int_flights__weather_at_departure') }}
)

select
    flight_id,
    reporting_airline,
    flight_number,
    origin,
    dest,
    flight_date,
    year_month,
    dep_time_utc,
    dep_time_source,
    origin_timezone,
    extract(hour from dep_time_utc at time zone 'UTC')::int as dep_hour_utc,
    extract(isodow from dep_time_utc at time zone 'UTC')::int as dep_dow,
    extract(month from dep_time_utc at time zone 'UTC')::int as dep_month,
    dep_delay_minutes,
    is_dep_delay_15_plus,
    is_cancelled,
    is_diverted,
    not is_cancelled and not is_diverted as is_analysis_eligible,
    weather_match_status,
    weather_match_status = 'matched' as has_departure_weather,
    weather_valid_utc,
    weather_obs_lag_minutes,
    temperature_f,
    dewpoint_f,
    relative_humidity_pct,
    wind_direction_deg,
    wind_speed_knots,
    wind_gust_knots,
    precip_1hr_inches,
    altimeter_inhg,
    sea_level_pressure_hpa,
    visibility_miles,
    weather_codes
from flights
