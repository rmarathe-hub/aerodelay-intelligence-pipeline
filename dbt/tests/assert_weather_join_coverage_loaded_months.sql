-- Match rate must be >= 90% on loaded weather station-months only.
-- Do not gate global all-flight match rate until full weather backfill is complete.
with loaded_scope as (
    select *
    from (
        values
            ('ATL', '2025-01'),
            ('ORD', '2025-01'),
            ('LAX', '2025-01'),
            ('DEN', '2025-02')
    ) as t(origin, year_month)
),

station_month_stats as (
    select
        f.origin,
        f.year_month,
        count(*) as flights,
        count(*) filter (where f.weather_match_status = 'matched') as matched_flights,
        round(
            100.0 * count(*) filter (where f.weather_match_status = 'matched') / nullif(count(*), 0),
            2
        ) as match_pct
    from {{ ref('int_flights__weather_at_departure') }} as f
    inner join loaded_scope as s
        on f.origin = s.origin
        and f.year_month = s.year_month
    group by f.origin, f.year_month
)

select
    origin,
    year_month,
    flights,
    matched_flights,
    match_pct
from station_month_stats
where match_pct < 90
