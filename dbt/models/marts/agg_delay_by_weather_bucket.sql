with eligible_flights as (
    select
        origin,
        wind_speed_knots,
        precip_1hr_inches,
        visibility_miles,
        dep_delay_minutes,
        is_dep_delay_15_plus
    from {{ ref('fct_flights') }}
    where is_analysis_eligible
      and has_departure_weather
),

bucketed as (
    select
        origin,
        dep_delay_minutes,
        is_dep_delay_15_plus,
        case
            when wind_speed_knots is null then 'unknown'
            when wind_speed_knots <= 5 then 'calm_0_5kt'
            when wind_speed_knots <= 15 then 'light_6_15kt'
            when wind_speed_knots <= 25 then 'moderate_16_25kt'
            else 'strong_26plus_kt'
        end as wind_speed_bucket,
        case
            when coalesce(precip_1hr_inches, 0) = 0 then 'none'
            when precip_1hr_inches <= 0.1 then 'light'
            when precip_1hr_inches <= 0.3 then 'moderate'
            else 'heavy'
        end as precip_bucket,
        case
            when visibility_miles is null then 'unknown'
            when visibility_miles < 3 then 'low_under_3mi'
            when visibility_miles <= 10 then 'medium_3_10mi'
            else 'high_over_10mi'
        end as visibility_bucket
    from eligible_flights
)

select
    origin,
    wind_speed_bucket,
    precip_bucket,
    visibility_bucket,
    count(*) as flight_count,
    count(*) filter (where is_dep_delay_15_plus) as delayed_count,
    round(
        count(*) filter (where is_dep_delay_15_plus)::numeric / nullif(count(*), 0),
        4
    ) as delay_rate_15,
    round(avg(dep_delay_minutes)::numeric, 2) as avg_dep_delay_minutes
from bucketed
group by origin, wind_speed_bucket, precip_bucket, visibility_bucket
