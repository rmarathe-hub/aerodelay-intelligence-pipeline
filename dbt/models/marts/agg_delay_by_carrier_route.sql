with eligible_flights as (
    select
        reporting_airline,
        origin,
        dest,
        dep_delay_minutes,
        is_dep_delay_15_plus
    from {{ ref('fct_flights') }}
    where is_analysis_eligible
)

select
    reporting_airline,
    origin,
    dest,
    count(*) as flight_count,
    count(*) filter (where is_dep_delay_15_plus) as delayed_count,
    round(
        count(*) filter (where is_dep_delay_15_plus)::numeric / nullif(count(*), 0),
        4
    ) as delay_rate_15,
    round(avg(dep_delay_minutes)::numeric, 2) as avg_dep_delay_minutes
from eligible_flights
group by reporting_airline, origin, dest
