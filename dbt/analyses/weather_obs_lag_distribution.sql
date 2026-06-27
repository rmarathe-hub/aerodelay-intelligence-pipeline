{#-
  weather_obs_lag_minutes distribution for matched flights on loaded station-months.
  Lag = dep_time_utc - weather_valid_utc (minutes); positive = obs before departure.

  Expect: median near 0, most lags small (minutes not hours), no ±300 min timezone offset.
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

matched as (
    select
        f.origin as airport_code,
        f.year_month,
        f.weather_obs_lag_minutes,
        case
            when f.weather_obs_lag_minutes > 0 then 'obs_before_dep'
            when f.weather_obs_lag_minutes = 0 then 'obs_at_dep'
            when f.weather_obs_lag_minutes < 0 then 'obs_after_dep'
        end as obs_timing
    from {{ ref('int_flights__weather_at_departure') }} as f
    inner join scope as s
        on f.origin = s.airport_code
        and f.year_month = s.year_month
    where f.weather_match_status = 'matched'
      and f.weather_obs_lag_minutes is not null
),

percentiles as (
    select
        'percentile' as report,
        airport_code,
        year_month,
        null::text as bucket,
        count(*) as matched_flights,
        round(min(weather_obs_lag_minutes)::numeric, 2) as lag_min,
        round(max(weather_obs_lag_minutes)::numeric, 2) as lag_max,
        round(avg(weather_obs_lag_minutes)::numeric, 2) as lag_avg,
        round(
            percentile_cont(0.5) within group (order by weather_obs_lag_minutes)::numeric,
            2
        ) as lag_p50,
        round(
            percentile_cont(0.9) within group (order by weather_obs_lag_minutes)::numeric,
            2
        ) as lag_p90,
        round(
            percentile_cont(0.99) within group (order by weather_obs_lag_minutes)::numeric,
            2
        ) as lag_p99,
        null::bigint as obs_before_dep,
        null::bigint as obs_at_dep,
        null::bigint as obs_after_dep
    from matched
    group by airport_code, year_month
),

timing_split as (
    select
        'timing_split' as report,
        airport_code,
        year_month,
        null::text as bucket,
        count(*) as matched_flights,
        null::numeric as lag_min,
        null::numeric as lag_max,
        null::numeric as lag_avg,
        null::numeric as lag_p50,
        null::numeric as lag_p90,
        null::numeric as lag_p99,
        count(*) filter (where obs_timing = 'obs_before_dep') as obs_before_dep,
        count(*) filter (where obs_timing = 'obs_at_dep') as obs_at_dep,
        count(*) filter (where obs_timing = 'obs_after_dep') as obs_after_dep
    from matched
    group by airport_code, year_month
),

histogram as (
    select
        'histogram' as report,
        airport_code,
        year_month,
        case
            when weather_obs_lag_minutes >= 60 then 'lag_gte_60m'
            when weather_obs_lag_minutes >= 30 then 'lag_30_to_60m'
            when weather_obs_lag_minutes >= 10 then 'lag_10_to_30m'
            when weather_obs_lag_minutes > 0 then 'lag_0_to_10m'
            when weather_obs_lag_minutes = 0 then 'lag_0m'
            when weather_obs_lag_minutes >= -10 then 'lag_neg_0_to_10m'
            when weather_obs_lag_minutes >= -30 then 'lag_neg_10_to_30m'
            when weather_obs_lag_minutes >= -60 then 'lag_neg_30_to_60m'
            else 'lag_lt_neg_60m'
        end as bucket,
        count(*) as matched_flights,
        null::numeric as lag_min,
        null::numeric as lag_max,
        null::numeric as lag_avg,
        null::numeric as lag_p50,
        null::numeric as lag_p90,
        null::numeric as lag_p99,
        null::bigint as obs_before_dep,
        null::bigint as obs_at_dep,
        null::bigint as obs_after_dep
    from matched
    group by airport_code, year_month, 4
)

select * from percentiles
union all
select * from timing_split
union all
select * from histogram
order by report, airport_code, year_month, bucket nulls first
