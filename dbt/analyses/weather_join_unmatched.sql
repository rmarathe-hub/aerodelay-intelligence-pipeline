{#-
  Unmatched flight diagnostics on loaded station-months (weather_match_status = no_obs_in_window).
  Expect low-match days at month-end when weather files end early (Jan 30-31, Feb 27-28).
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

scoped_flights as (
    select
        f.origin as airport_code,
        f.year_month,
        f.flight_date,
        f.flight_id,
        f.dep_time_utc,
        f.weather_match_status
    from {{ ref('int_flights__weather_at_departure') }} as f
    inner join scope as s
        on f.origin = s.airport_code
        and f.year_month = s.year_month
),

by_date as (
    select
        'by_date' as report,
        airport_code,
        year_month,
        flight_date,
        count(*) as flights,
        count(*) filter (where weather_match_status = 'matched') as matched_flights,
        count(*) filter (where weather_match_status = 'no_obs_in_window') as unmatched_flights,
        round(
            100.0 * count(*) filter (where weather_match_status = 'matched') / nullif(count(*), 0),
            2
        ) as match_pct
    from scoped_flights
    group by airport_code, year_month, flight_date
),

airport_totals as (
    select
        'airport_total' as report,
        airport_code,
        year_month,
        null::date as flight_date,
        count(*) as flights,
        count(*) filter (where weather_match_status = 'matched') as matched_flights,
        count(*) filter (where weather_match_status = 'no_obs_in_window') as unmatched_flights,
        round(
            100.0 * count(*) filter (where weather_match_status = 'matched') / nullif(count(*), 0),
            2
        ) as match_pct
    from scoped_flights
    group by airport_code, year_month
),

worst_days as (
    select *
    from by_date
    where match_pct < 100
)

select
    report,
    airport_code,
    year_month,
    flight_date,
    flights,
    matched_flights,
    unmatched_flights,
    match_pct
from airport_totals

union all

select
    'worst_day' as report,
    airport_code,
    year_month,
    flight_date,
    flights,
    matched_flights,
    unmatched_flights,
    match_pct
from worst_days

union all

select
    'sample_unmatched' as report,
    airport_code,
    year_month,
    flight_date,
    null::bigint as flights,
    null::bigint as matched_flights,
    null::bigint as unmatched_flights,
    null::numeric as match_pct
from (
    select distinct
        airport_code,
        year_month,
        flight_date
    from scoped_flights
    where weather_match_status = 'no_obs_in_window'
    order by flight_date desc, airport_code
    limit 20
) as sample_dates

order by report, airport_code, year_month, flight_date nulls first, match_pct nulls first
