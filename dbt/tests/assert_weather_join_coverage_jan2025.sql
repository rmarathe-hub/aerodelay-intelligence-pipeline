-- Match rate >= 90% for all Jan 2025 origins except HNL (IEM station is PHNL, not HNL).
with airport_stats as (
    select
        f.origin,
        count(*) as flights,
        count(*) filter (where f.weather_match_status = 'matched') as matched_flights,
        round(
            100.0 * count(*) filter (where f.weather_match_status = 'matched') / nullif(count(*), 0),
            2
        ) as match_pct
    from {{ ref('int_flights__weather_at_departure') }} as f
    where f.year_month = '2025-01'
      and f.origin <> 'HNL'
    group by f.origin
)

select
    origin,
    flights,
    matched_flights,
    match_pct
from airport_stats
where match_pct < 90
