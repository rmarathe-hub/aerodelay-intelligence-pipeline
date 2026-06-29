{#-
  Delay rates by departure weather bins (wind, precip, visibility).

  Scope: marts.agg_delay_by_weather_bucket (analysis-eligible flights with matched weather).
  Pooled sections aggregate across all origins; origin sections show airport-level hotspots.
-#}

with base as (
    select *
    from {{ ref('agg_delay_by_weather_bucket') }}
),

by_wind as (
    select
        'pooled_wind' as report,
        wind_speed_bucket as bucket_value,
        null::text as origin,
        sum(flight_count) as flight_count,
        sum(delayed_count) as delayed_count,
        round(sum(delayed_count)::numeric / nullif(sum(flight_count), 0), 4) as delay_rate_15,
        round(
            sum(avg_dep_delay_minutes * flight_count)::numeric / nullif(sum(flight_count), 0),
            2
        ) as avg_dep_delay_minutes
    from base
    group by wind_speed_bucket
),

by_precip as (
    select
        'pooled_precip' as report,
        precip_bucket as bucket_value,
        null::text as origin,
        sum(flight_count) as flight_count,
        sum(delayed_count) as delayed_count,
        round(sum(delayed_count)::numeric / nullif(sum(flight_count), 0), 4) as delay_rate_15,
        round(
            sum(avg_dep_delay_minutes * flight_count)::numeric / nullif(sum(flight_count), 0),
            2
        ) as avg_dep_delay_minutes
    from base
    group by precip_bucket
),

by_visibility as (
    select
        'pooled_visibility' as report,
        visibility_bucket as bucket_value,
        null::text as origin,
        sum(flight_count) as flight_count,
        sum(delayed_count) as delayed_count,
        round(sum(delayed_count)::numeric / nullif(sum(flight_count), 0), 4) as delay_rate_15,
        round(
            sum(avg_dep_delay_minutes * flight_count)::numeric / nullif(sum(flight_count), 0),
            2
        ) as avg_dep_delay_minutes
    from base
    group by visibility_bucket
),

worst_combos as (
    select
        'worst_weather_combo' as report,
        wind_speed_bucket || ' | ' || precip_bucket || ' | ' || visibility_bucket as bucket_value,
        origin,
        flight_count,
        delayed_count,
        delay_rate_15,
        avg_dep_delay_minutes,
        row_number() over (
            order by delay_rate_15 desc, flight_count desc, origin
        ) as rank
    from base
    where flight_count >= 50
)

select
    report,
    bucket_value,
    origin,
    flight_count,
    delayed_count,
    delay_rate_15,
    avg_dep_delay_minutes,
    null::bigint as rank
from by_wind

union all

select
    report,
    bucket_value,
    origin,
    flight_count,
    delayed_count,
    delay_rate_15,
    avg_dep_delay_minutes,
    null::bigint as rank
from by_precip

union all

select
    report,
    bucket_value,
    origin,
    flight_count,
    delayed_count,
    delay_rate_15,
    avg_dep_delay_minutes,
    null::bigint as rank
from by_visibility

union all

select
    report,
    bucket_value,
    origin,
    flight_count,
    delayed_count,
    delay_rate_15,
    avg_dep_delay_minutes,
    rank
from worst_combos
where rank <= 10

order by report, rank nulls first, delay_rate_15 desc
