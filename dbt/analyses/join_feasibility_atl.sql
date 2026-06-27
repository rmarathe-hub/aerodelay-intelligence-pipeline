{#-
  ATL Jan 2025 join feasibility: flights vs weather within ±2h of dep_time_utc.
  No nearest-observation join — existence check only.
  Run: bash scripts/dbt_run.sh compile && psql -f target/compiled/.../join_feasibility_atl.sql
-#}

with flights as (
    select
        flight_id,
        flight_date,
        dep_time_utc,
        dep_time_source,
        is_cancelled
    from {{ ref('int_flights__departure_context') }}
    where origin = 'ATL'
      and year_month = '2025-01'
      and dep_time_utc is not null
),

weather as (
    select valid_utc
    from {{ ref('int_weather__observations_enriched') }}
    where airport_code = 'ATL'
      and year_month = '2025-01'
),

matched_flight_ids as (
    select distinct f.flight_id
    from flights as f
    inner join weather as w
        on w.airport_code = f.airport_code
        and w.valid_utc between f.dep_time_utc - interval '2 hours'
            and f.dep_time_utc + interval '2 hours'
),

matched as (
    select
        f.*,
        (m.flight_id is not null) as has_weather_within_2h
    from flights as f
    left join matched_flight_ids as m on f.flight_id = m.flight_id
)

select
    'ATL' as airport_code,
    '2025-01' as year_month,
    (select count(*) from weather) as weather_obs_count,
    (select min(valid_utc) from weather) as weather_min_utc,
    (select max(valid_utc) from weather) as weather_max_utc,
    count(*) as flights_with_dep_time,
    count(*) filter (where has_weather_within_2h) as flights_matched,
    count(*) filter (where not has_weather_within_2h) as flights_unmatched,
    round(
        100.0 * count(*) filter (where has_weather_within_2h) / nullif(count(*), 0),
        2
    ) as match_pct
from matched
