{#-
  Top departure delay hotspots by origin airport and UTC hour.

  Scope: marts.agg_delay_by_airport_hour (Jan 2025 sample when fct_flights is materialized with dev_year_month).
  Filters noisy buckets with flight_count >= 100 unless noted.
-#}

with base as (
    select *
    from {{ ref('agg_delay_by_airport_hour') }}
),

top_delay_rate as (
    select
        'top_delay_rate' as report,
        origin,
        dep_hour_utc,
        flight_count,
        delayed_count,
        delay_rate_15,
        avg_dep_delay_minutes,
        row_number() over (
            order by delay_rate_15 desc, flight_count desc, origin, dep_hour_utc
        ) as rank
    from base
    where flight_count >= 100
),

top_avg_delay as (
    select
        'top_avg_delay_minutes' as report,
        origin,
        dep_hour_utc,
        flight_count,
        delayed_count,
        delay_rate_15,
        avg_dep_delay_minutes,
        row_number() over (
            order by avg_dep_delay_minutes desc, flight_count desc, origin, dep_hour_utc
        ) as rank
    from base
    where flight_count >= 100
),

busiest_hours as (
    select
        'busiest_hour' as report,
        origin,
        dep_hour_utc,
        flight_count,
        delayed_count,
        delay_rate_15,
        avg_dep_delay_minutes,
        row_number() over (
            order by flight_count desc, origin, dep_hour_utc
        ) as rank
    from base
),

airport_summary as (
    select
        origin,
        sum(flight_count) as flight_count,
        sum(delayed_count) as delayed_count,
        round(sum(delayed_count)::numeric / nullif(sum(flight_count), 0), 4) as delay_rate_15,
        round(
            sum(avg_dep_delay_minutes * flight_count)::numeric / nullif(sum(flight_count), 0),
            2
        ) as avg_dep_delay_minutes
    from base
    group by origin
),

top_airport_delay_rate as (
    select
        'top_airport_delay_rate' as report,
        origin,
        null::int as dep_hour_utc,
        flight_count,
        delayed_count,
        delay_rate_15,
        avg_dep_delay_minutes,
        row_number() over (
            order by delay_rate_15 desc, flight_count desc, origin
        ) as rank
    from airport_summary
    where flight_count >= 500
)

select
    report,
    origin,
    dep_hour_utc,
    flight_count,
    delayed_count,
    delay_rate_15,
    avg_dep_delay_minutes,
    rank
from top_delay_rate
where rank <= 10

union all

select
    report,
    origin,
    dep_hour_utc,
    flight_count,
    delayed_count,
    delay_rate_15,
    avg_dep_delay_minutes,
    rank
from top_avg_delay
where rank <= 10

union all

select
    report,
    origin,
    dep_hour_utc,
    flight_count,
    delayed_count,
    delay_rate_15,
    avg_dep_delay_minutes,
    rank
from busiest_hours
where rank <= 10

union all

select
    report,
    origin,
    dep_hour_utc,
    flight_count,
    delayed_count,
    delay_rate_15,
    avg_dep_delay_minutes,
    rank
from top_airport_delay_rate
where rank <= 10

order by report, rank
