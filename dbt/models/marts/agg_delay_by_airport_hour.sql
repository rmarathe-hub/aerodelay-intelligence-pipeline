with eligible_flights as (
    select
        origin,
        dep_hour_utc,
        dep_delay_minutes,
        is_dep_delay_15_plus
    from {{ ref('fct_flights') }}
    where is_analysis_eligible
)

select
    origin,
    dep_hour_utc,
    count(*) as flight_count,
    count(*) filter (where is_dep_delay_15_plus) as delayed_count,
    round(
        count(*) filter (where is_dep_delay_15_plus)::numeric / nullif(count(*), 0),
        4
    ) as delay_rate_15,
    round(avg(dep_delay_minutes)::numeric, 2) as avg_dep_delay_minutes
from eligible_flights
group by origin, dep_hour_utc
