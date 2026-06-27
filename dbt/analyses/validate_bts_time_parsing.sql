{#-
  Spot-check BTS HHMM parsing macros against dim_airports timezones.
  Run: bash scripts/dbt_run.sh compile
  Then inspect compiled SQL under target/compiled/.../analyses/
  Or paste compiled query into psql.
-#}

with samples as (
    select *
    from (
        values
            ('ATL', date '2025-01-15', '800'),
            ('ATL', date '2025-01-15', '1530'),
            ('ATL', date '2025-01-15', '1'),
            ('ATL', date '2025-01-15', '2400'),
            ('ATL', date '2025-01-15', null),
            ('DEN', date '2025-02-01', '930'),
            ('LAX', date '2025-01-15', '745'),
            ('ORD', date '2025-01-15', '1200')
    ) as v(airport_code, flight_date, hhmm)
),

parsed as (
    select
        s.airport_code,
        s.flight_date,
        s.hhmm,
        a.timezone,
        {{ bts_time_to_timestamp('s.flight_date', 's.hhmm') }} as local_ts,
        {{ bts_time_to_utc('s.flight_date', 's.hhmm', 'a.timezone') }} as utc_ts
    from samples as s
    inner join {{ ref('dim_airports') }} as a on s.airport_code = a.airport_code
)

select
    airport_code,
    flight_date,
    hhmm,
    timezone,
    local_ts,
    utc_ts,
    utc_ts at time zone timezone as utc_as_local_check
from parsed
order by airport_code, hhmm nulls last
