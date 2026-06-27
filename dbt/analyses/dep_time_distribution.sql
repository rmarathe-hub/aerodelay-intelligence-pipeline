{#-
  dep_time_utc distribution and timezone sanity checks for loaded station-months.
  Flags outliers (before 1970 or after 2030) and shows UTC hour volume by airport.
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
        f.origin as airport_code,
        f.year_month,
        f.flight_date,
        f.dep_time_utc,
        f.dep_time_source,
        extract(hour from f.dep_time_utc at time zone 'UTC')::int as dep_hour_utc,
        case
            when f.dep_time_utc < timestamptz '1970-01-01' then 'before_1970'
            when f.dep_time_utc >= timestamptz '2030-01-01' then 'after_2030'
            when f.dep_time_utc is null then 'null_dep_time'
            else 'ok'
        end as dep_time_sanity
    from {{ ref('int_flights__departure_context') }} as f
    inner join scope as s
        on f.origin = s.airport_code
        and f.year_month = s.year_month
)

select
    'sanity' as report,
    airport_code,
    dep_time_sanity,
    null::int as dep_hour_utc,
    count(*) as flights
from flights
group by airport_code, dep_time_sanity

union all

select
    'hour_distribution' as report,
    airport_code,
    'ok' as dep_time_sanity,
    dep_hour_utc,
    count(*) as flights
from flights
where dep_time_sanity = 'ok'
group by airport_code, dep_hour_utc

order by report, airport_code, dep_time_sanity, dep_hour_utc nulls first
