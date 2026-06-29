{#-
  Top carrier routes by volume and delay rate.

  Scope: marts.agg_delay_by_carrier_route (analysis-eligible flights).
-#}

with base as (
    select *
    from {{ ref('agg_delay_by_carrier_route') }}
),

top_volume as (
    select
        'top_volume' as report,
        reporting_airline,
        origin,
        dest,
        flight_count,
        delayed_count,
        delay_rate_15,
        avg_dep_delay_minutes,
        row_number() over (
            order by flight_count desc, reporting_airline, origin, dest
        ) as rank
    from base
),

top_delay_rate as (
    select
        'top_delay_rate' as report,
        reporting_airline,
        origin,
        dest,
        flight_count,
        delayed_count,
        delay_rate_15,
        avg_dep_delay_minutes,
        row_number() over (
            order by delay_rate_15 desc, flight_count desc, reporting_airline, origin, dest
        ) as rank
    from base
    where flight_count >= 50
)

select
    report,
    reporting_airline,
    origin,
    dest,
    flight_count,
    delayed_count,
    delay_rate_15,
    avg_dep_delay_minutes,
    rank
from top_volume
where rank <= 10

union all

select
    report,
    reporting_airline,
    origin,
    dest,
    flight_count,
    delayed_count,
    delay_rate_15,
    avg_dep_delay_minutes,
    rank
from top_delay_rate
where rank <= 10

order by report, rank
