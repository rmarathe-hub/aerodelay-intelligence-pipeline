{% set window_hours = var('weather_join_window_hours') %}

with flights as (
    select * from {{ ref('int_flights__departure_context') }}
),

weather as (
    select * from {{ ref('int_weather__observations_enriched') }}
),

candidates as (
    select
        f.flight_id,
        w.weather_station_id,
        w.valid_utc as weather_valid_utc,
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
        w.loaded_at as weather_loaded_at,
        abs(extract(epoch from (w.valid_utc - f.dep_time_utc))) as obs_delta_seconds,
        case
            when w.valid_utc <= f.dep_time_utc then 0
            else 1
        end as obs_after_dep_rank
    from flights as f
    inner join weather as w
        on w.airport_code = f.origin
        and w.valid_utc >= f.dep_time_utc - (interval '1 hour' * {{ window_hours }})
        and w.valid_utc <= f.dep_time_utc + (interval '1 hour' * {{ window_hours }})
    where f.dep_time_utc is not null
),

ranked as (
    select
        *,
        row_number() over (
            partition by flight_id
            order by
                obs_delta_seconds asc,
                obs_after_dep_rank asc,
                weather_loaded_at desc
        ) as candidate_rank
    from candidates
),

best_match as (
    select
        flight_id,
        weather_station_id,
        weather_valid_utc,
        temperature_f,
        dewpoint_f,
        relative_humidity_pct,
        wind_direction_deg,
        wind_speed_knots,
        precip_1hr_inches,
        altimeter_inhg,
        sea_level_pressure_hpa,
        visibility_miles,
        wind_gust_knots,
        sky_cover_1,
        sky_cover_2,
        sky_cover_3,
        sky_cover_4,
        sky_layer_1_ft,
        sky_layer_2_ft,
        sky_layer_3_ft,
        sky_layer_4_ft,
        weather_codes,
        feels_like_f,
        metar_raw,
        snow_depth_inches
    from ranked
    where candidate_rank = 1
)

select
    f.flight_id,
    f.reporting_airline,
    f.flight_number,
    f.tail_number,
    f.origin,
    f.origin_city_name,
    f.origin_state,
    f.dest,
    f.dest_city_name,
    f.dest_state,
    f.flight_date,
    f.flight_year,
    f.flight_month,
    f.day_of_week,
    f.origin_timezone,
    f.origin_weather_station_id,
    f.dest_timezone,
    f.crs_dep_time_hhmm,
    f.crs_dep_time_local,
    f.crs_dep_time_utc,
    f.dep_time_hhmm,
    f.dep_time_local,
    f.actual_dep_time_utc,
    f.dep_time_utc,
    f.dep_time_source,
    f.crs_arr_time_hhmm,
    f.crs_arr_time_local,
    f.crs_arr_time_utc,
    f.arr_time_hhmm,
    f.arr_time_local,
    f.arr_time_utc,
    f.is_cancelled,
    f.is_diverted,
    f.cancellation_code,
    f.dep_delay_minutes,
    f.dep_delay_minutes_nonneg,
    f.is_dep_delay_15_plus,
    f.arr_delay_minutes,
    f.arr_delay_minutes_nonneg,
    f.is_arr_delay_15_plus,
    f.carrier_delay_minutes,
    f.weather_delay_minutes,
    f.nas_delay_minutes,
    f.security_delay_minutes,
    f.late_aircraft_delay_minutes,
    f.taxi_out_minutes,
    f.taxi_in_minutes,
    f.air_time_minutes,
    f.actual_elapsed_minutes,
    f.scheduled_elapsed_minutes,
    f.distance_miles,
    f.distance_group,
    f.flights_count,
    f.year_month,
    f.source_file,
    f.loaded_at,
    f.run_id,
    case
        when bm.weather_valid_utc is not null then 'matched'
        else 'no_obs_in_window'
    end as weather_match_status,
    bm.weather_station_id as matched_weather_station_id,
    bm.weather_valid_utc,
    case
        when bm.weather_valid_utc is not null
            then extract(epoch from (f.dep_time_utc - bm.weather_valid_utc)) / 60.0
    end as weather_obs_lag_minutes,
    bm.temperature_f,
    bm.dewpoint_f,
    bm.relative_humidity_pct,
    bm.wind_direction_deg,
    bm.wind_speed_knots,
    bm.precip_1hr_inches,
    bm.altimeter_inhg,
    bm.sea_level_pressure_hpa,
    bm.visibility_miles,
    bm.wind_gust_knots,
    bm.sky_cover_1,
    bm.sky_cover_2,
    bm.sky_cover_3,
    bm.sky_cover_4,
    bm.sky_layer_1_ft,
    bm.sky_layer_2_ft,
    bm.sky_layer_3_ft,
    bm.sky_layer_4_ft,
    bm.weather_codes,
    bm.feels_like_f,
    bm.metar_raw,
    bm.snow_depth_inches
from flights as f
left join best_match as bm on f.flight_id = bm.flight_id
