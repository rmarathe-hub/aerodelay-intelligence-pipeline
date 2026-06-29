{#-
  Weather join coverage for all loaded airports in Jan 2025.

  Scope: year_month = '2025-01' on int_flights__weather_at_departure.
  Replaces the legacy 4-month scope in weather_join_coverage.sql for portfolio/dev sample runs.
-#}

with flights as (
    select
        f.origin as airport_code,
        f.year_month,
        f.flight_date,
        extract(hour from f.dep_time_utc at time zone 'UTC')::int as dep_hour_utc,
        (f.weather_match_status = 'matched') as is_matched
    from {{ ref('int_flights__weather_at_departure') }} as f
    where f.year_month = '2025-01'
),

airport_summary as (
    select
        'airport' as grain,
        airport_code,
        year_month,
        null::date as flight_date,
        null::int as dep_hour_utc,
        count(*) as flights,
        count(*) filter (where is_matched) as matched_flights,
        round(
            100.0 * count(*) filter (where is_matched) / nullif(count(*), 0),
            2
        ) as match_pct
    from flights
    group by airport_code, year_month
),

overall as (
    select
        'overall' as grain,
        'ALL' as airport_code,
        '2025-01' as year_month,
        null::date as flight_date,
        null::int as dep_hour_utc,
        count(*) as flights,
        count(*) filter (where is_matched) as matched_flights,
        round(
            100.0 * count(*) filter (where is_matched) / nullif(count(*), 0),
            2
        ) as match_pct
    from flights
),

low_match_airports as (
    select *
    from airport_summary
    where match_pct < 90.0
),

combined as (
    select * from overall
    union all
    select * from airport_summary
    union all
    select
        'low_match_airport' as grain,
        airport_code,
        year_month,
        flight_date,
        dep_hour_utc,
        flights,
        matched_flights,
        match_pct
    from low_match_airports
)

select
    grain,
    airport_code,
    year_month,
    flight_date,
    dep_hour_utc,
    flights,
    matched_flights,
    match_pct
from combined
order by
    case grain when 'overall' then 0 when 'low_match_airport' then 1 else 2 end,
    match_pct nulls first,
    airport_code
