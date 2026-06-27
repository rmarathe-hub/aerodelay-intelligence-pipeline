with source as (
    select * from {{ source('raw', 'bts_flights') }}
),

typed as (
    select
        {{ clean_text('"Reporting_Airline"') }} as reporting_airline,
        {{ clean_text('"Flight_Number_Reporting_Airline"') }} as flight_number,
        {{ clean_text('"Tail_Number"') }} as tail_number,
        {{ clean_text('"Origin"') }} as origin,
        {{ clean_text('"OriginCityName"') }} as origin_city_name,
        {{ clean_text('"OriginState"') }} as origin_state,
        {{ clean_text('"Dest"') }} as dest,
        {{ clean_text('"DestCityName"') }} as dest_city_name,
        {{ clean_text('"DestState"') }} as dest_state,
        {{ clean_text('"FlightDate"') }}::date as flight_date,
        {{ clean_numeric('"Year"') }}::integer as flight_year,
        {{ clean_numeric('"Month"') }}::integer as flight_month,
        {{ clean_numeric('"DayOfWeek"') }}::integer as day_of_week,
        {{ clean_text('"CRSDepTime"') }} as crs_dep_time_local,
        {{ clean_text('"DepTime"') }} as dep_time_local,
        {{ clean_text('"CRSArrTime"') }} as crs_arr_time_local,
        {{ clean_text('"ArrTime"') }} as arr_time_local,
        {{ clean_text('"WheelsOff"') }} as wheels_off_local,
        {{ clean_text('"WheelsOn"') }} as wheels_on_local,
        coalesce(nullif(trim("Cancelled"::text), ''), '0')::numeric = 1 as is_cancelled,
        coalesce(nullif(trim("Diverted"::text), ''), '0')::numeric = 1 as is_diverted,
        {{ clean_text('"CancellationCode"') }} as cancellation_code,
        case
            when coalesce(nullif(trim("Cancelled"::text), ''), '0')::numeric = 1 then null
            else {{ clean_numeric('"DepDelay"') }}
        end as dep_delay_minutes,
        case
            when coalesce(nullif(trim("Cancelled"::text), ''), '0')::numeric = 1 then null
            else {{ clean_numeric('"DepDelayMinutes"') }}
        end as dep_delay_minutes_nonneg,
        case
            when coalesce(nullif(trim("Cancelled"::text), ''), '0')::numeric = 1 then null
            else coalesce(nullif(trim("DepDel15"::text), ''), '0')::numeric = 1
        end as is_dep_delay_15_plus,
        case
            when coalesce(nullif(trim("Cancelled"::text), ''), '0')::numeric = 1 then null
            else {{ clean_numeric('"ArrDelay"') }}
        end as arr_delay_minutes,
        case
            when coalesce(nullif(trim("Cancelled"::text), ''), '0')::numeric = 1 then null
            else {{ clean_numeric('"ArrDelayMinutes"') }}
        end as arr_delay_minutes_nonneg,
        case
            when coalesce(nullif(trim("Cancelled"::text), ''), '0')::numeric = 1 then null
            else coalesce(nullif(trim("ArrDel15"::text), ''), '0')::numeric = 1
        end as is_arr_delay_15_plus,
        {{ clean_numeric('"CarrierDelay"') }} as carrier_delay_minutes,
        {{ clean_numeric('"WeatherDelay"') }} as weather_delay_minutes,
        {{ clean_numeric('"NASDelay"') }} as nas_delay_minutes,
        {{ clean_numeric('"SecurityDelay"') }} as security_delay_minutes,
        {{ clean_numeric('"LateAircraftDelay"') }} as late_aircraft_delay_minutes,
        {{ clean_numeric('"TaxiOut"') }} as taxi_out_minutes,
        {{ clean_numeric('"TaxiIn"') }} as taxi_in_minutes,
        {{ clean_numeric('"AirTime"') }} as air_time_minutes,
        {{ clean_numeric('"ActualElapsedTime"') }} as actual_elapsed_minutes,
        {{ clean_numeric('"CRSElapsedTime"') }} as scheduled_elapsed_minutes,
        {{ clean_numeric('"Distance"') }} as distance_miles,
        {{ clean_numeric('"DistanceGroup"') }}::integer as distance_group,
        {{ clean_numeric('"Flights"') }} as flights_count,
        year_month,
        source_file,
        loaded_at,
        run_id
    from source
),

with_keys as (
    select
        *,
        md5(
            concat_ws(
                '|',
                coalesce(reporting_airline, ''),
                coalesce(flight_number, ''),
                coalesce(origin, ''),
                coalesce(flight_date::text, ''),
                coalesce(crs_dep_time_local, '')
            )
        ) as flight_id
    from typed
)

select * from with_keys
