with weather as (
    select * from {{ ref('stg_weather__observations') }}
),

airports as (
    select * from {{ ref('dim_airports') }}
)

select
    w.station as weather_station_id,
    a.airport_code,
    a.airport_name,
    a.timezone as airport_timezone,
    w.valid_utc,
    w.temperature_f,
    w.dewpoint_f,
    w.relative_humidity_pct,
    w.wind_direction_deg,
    w.wind_speed_knots,
    w.precip_1hr_inches,
    w.altimeter_inhg,
    w.sea_level_pressure_hpa,
    w.visibility_miles,
    w.wind_gust_knots,
    w.sky_cover_1,
    w.sky_cover_2,
    w.sky_cover_3,
    w.sky_cover_4,
    w.sky_layer_1_ft,
    w.sky_layer_2_ft,
    w.sky_layer_3_ft,
    w.sky_layer_4_ft,
    w.weather_codes,
    w.feels_like_f,
    w.metar_raw,
    w.snow_depth_inches,
    w.year_month,
    w.source_file,
    w.loaded_at,
    w.run_id
from weather as w
inner join airports as a on w.station = a.weather_station_id
