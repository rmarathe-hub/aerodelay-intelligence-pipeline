{#-
  Join feasibility for all loaded station-months:
    ATL Jan 2025, ORD Jan 2025, LAX Jan 2025, DEN Feb 2025

  Candidate match = ≥1 weather obs within ±2h of dep_time_utc at origin airport.
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
        extract(hour from f.dep_time_utc at time zone 'UTC')::int as dep_hour_utc
    from {{ ref('int_flights__departure_context') }} as f
    inner join scope as s
        on f.origin = s.airport_code
        and f.year_month = s.year_month
    where f.dep_time_utc is not null
),

weather as (
    select
        w.airport_code,
        w.year_month,
        w.valid_utc
    from {{ ref('int_weather__observations_enriched') }} as w
    inner join scope as s
        on w.airport_code = s.airport_code
        and w.year_month = s.year_month
),

matched_flight_ids as (
    select distinct f.flight_id
    from flights as f
    inner join weather as w
        on w.airport_code = f.airport_code
        and w.valid_utc between f.dep_time_utc - interval '2 hours'
            and f.dep_time_utc + interval '2 hours'
),

flight_matches as (
    select
        f.*,
        (m.flight_id is not null) as has_weather_within_2h
    from flights as f
    left join matched_flight_ids as m on f.flight_id = m.flight_id
),

airport_summary as (
    select
        'airport' as grain,
        airport_code,
        null::date as flight_date,
        null::int as dep_hour_utc,
        count(*) as flights,
        count(*) filter (where has_weather_within_2h) as matched_flights,
        round(
            100.0 * count(*) filter (where has_weather_within_2h) / nullif(count(*), 0),
            2
        ) as match_pct
    from flight_matches
    group by airport_code
),

by_date as (
    select
        'date' as grain,
        airport_code,
        flight_date,
        null::int as dep_hour_utc,
        count(*) as flights,
        count(*) filter (where has_weather_within_2h) as matched_flights,
        round(
            100.0 * count(*) filter (where has_weather_within_2h) / nullif(count(*), 0),
            2
        ) as match_pct
    from flight_matches
    group by airport_code, flight_date
),

by_hour as (
    select
        'hour' as grain,
        airport_code,
        null::date as flight_date,
        dep_hour_utc,
        count(*) as flights,
        count(*) filter (where has_weather_within_2h) as matched_flights,
        round(
            100.0 * count(*) filter (where has_weather_within_2h) / nullif(count(*), 0),
            2
        ) as match_pct
    from flight_matches
    group by airport_code, dep_hour_utc
)

select * from airport_summary
union all
select * from by_date
union all
select * from by_hour
order by grain, airport_code, flight_date nulls first, dep_hour_utc nulls first
