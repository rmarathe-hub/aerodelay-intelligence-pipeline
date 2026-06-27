{#-
  Nearest-obs join coverage on loaded station-months only:
    ATL Jan 2025, ORD Jan 2025, LAX Jan 2025, DEN Feb 2025

  Match = weather_match_status = 'matched' on int_flights__weather_at_departure.
  Compare airport summary to Day 13 feasibility (candidate obs within ±2h):
    ATL 95.99%, ORD 96.21%, LAX 95.80%, DEN 95.23%
  Grain: airport (summary), date (flight_date), hour (dep_hour_utc in UTC).
-#}

with scope as (
    select *
    from (
        values
            ('ATL', '2025-01'),
            ('ORD', '2025-01'),
            ('LAX', '2025-01'),
            ('DEN', '2025-02')
    ) as t(airport_code, year_month)
),

flights as (
    select
        f.flight_id,
        f.origin as airport_code,
        f.year_month,
        f.flight_date,
        f.dep_time_utc,
        f.weather_match_status,
        extract(hour from f.dep_time_utc at time zone 'UTC')::int as dep_hour_utc,
        (f.weather_match_status = 'matched') as is_matched
    from {{ ref('int_flights__weather_at_departure') }} as f
    inner join scope as s
        on f.origin = s.airport_code
        and f.year_month = s.year_month
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

by_date as (
    select
        'date' as grain,
        airport_code,
        year_month,
        flight_date,
        null::int as dep_hour_utc,
        count(*) as flights,
        count(*) filter (where is_matched) as matched_flights,
        round(
            100.0 * count(*) filter (where is_matched) / nullif(count(*), 0),
            2
        ) as match_pct
    from flights
    group by airport_code, year_month, flight_date
),

by_hour as (
    select
        'hour' as grain,
        airport_code,
        year_month,
        null::date as flight_date,
        dep_hour_utc,
        count(*) as flights,
        count(*) filter (where is_matched) as matched_flights,
        round(
            100.0 * count(*) filter (where is_matched) / nullif(count(*), 0),
            2
        ) as match_pct
    from flights
    group by airport_code, year_month, dep_hour_utc
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
from airport_summary
union all
select * from by_date
union all
select * from by_hour
order by grain, airport_code, year_month, flight_date nulls first, dep_hour_utc nulls first
