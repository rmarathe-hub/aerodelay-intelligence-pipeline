with flights as (
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
        f.crs_dep_time_local as crs_dep_time_hhmm,
        f.dep_time_local as dep_time_hhmm,
        f.crs_arr_time_local as crs_arr_time_hhmm,
        f.arr_time_local as arr_time_hhmm,
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
        origin_ap.timezone as origin_timezone,
        origin_ap.weather_station_id as origin_weather_station_id,
        dest_ap.timezone as dest_timezone
    from {{ ref('stg_bts__flights') }} as f
    inner join {{ ref('dim_airports') }} as origin_ap on f.origin = origin_ap.airport_code
    left join {{ ref('dim_airports') }} as dest_ap on f.dest = dest_ap.airport_code
),

parsed_times as (
    select
        *,
        {{ bts_time_to_timestamp('flight_date', 'crs_dep_time_hhmm') }} as crs_dep_time_local,
        {{ bts_time_to_utc('flight_date', 'crs_dep_time_hhmm', 'origin_timezone') }} as crs_dep_time_utc,
        {{ bts_time_to_timestamp('flight_date', 'dep_time_hhmm') }} as dep_time_local,
        {{ bts_time_to_utc('flight_date', 'dep_time_hhmm', 'origin_timezone') }} as actual_dep_time_utc,
        {{ bts_time_to_timestamp('flight_date', 'crs_arr_time_hhmm') }} as crs_arr_time_local,
        case
            when dest_timezone is not null
                then {{ bts_time_to_utc('flight_date', 'crs_arr_time_hhmm', 'dest_timezone') }}
        end as crs_arr_time_utc,
        {{ bts_time_to_timestamp('flight_date', 'arr_time_hhmm') }} as arr_time_local,
        case
            when dest_timezone is not null
                then {{ bts_time_to_utc('flight_date', 'arr_time_hhmm', 'dest_timezone') }}
        end as arr_time_utc
    from flights
),

departure_context as (
    select
        *,
        case
            when not is_cancelled and actual_dep_time_utc is not null
                then actual_dep_time_utc
            else crs_dep_time_utc
        end as dep_time_utc,
        case
            when not is_cancelled and actual_dep_time_utc is not null
                then 'actual'
            else 'scheduled'
        end as dep_time_source
    from parsed_times
)

select
    flight_id,
    reporting_airline,
    flight_number,
    tail_number,
    origin,
    origin_city_name,
    origin_state,
    dest,
    dest_city_name,
    dest_state,
    flight_date,
    flight_year,
    flight_month,
    day_of_week,
    origin_timezone,
    origin_weather_station_id,
    dest_timezone,
    crs_dep_time_hhmm,
    crs_dep_time_local,
    crs_dep_time_utc,
    dep_time_hhmm,
    dep_time_local,
    actual_dep_time_utc,
    dep_time_utc,
    dep_time_source,
    crs_arr_time_hhmm,
    crs_arr_time_local,
    crs_arr_time_utc,
    arr_time_hhmm,
    arr_time_local,
    arr_time_utc,
    is_cancelled,
    is_diverted,
    cancellation_code,
    dep_delay_minutes,
    dep_delay_minutes_nonneg,
    is_dep_delay_15_plus,
    arr_delay_minutes,
    arr_delay_minutes_nonneg,
    is_arr_delay_15_plus,
    carrier_delay_minutes,
    weather_delay_minutes,
    nas_delay_minutes,
    security_delay_minutes,
    late_aircraft_delay_minutes,
    taxi_out_minutes,
    taxi_in_minutes,
    air_time_minutes,
    actual_elapsed_minutes,
    scheduled_elapsed_minutes,
    distance_miles,
    distance_group,
    flights_count,
    year_month,
    source_file,
    loaded_at,
    run_id
from departure_context
