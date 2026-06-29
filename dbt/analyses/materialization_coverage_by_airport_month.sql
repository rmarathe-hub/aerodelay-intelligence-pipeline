-- Weather match coverage by origin airport and month.
select
    origin,
    year_month,
    count(*) as flights,
    count(*) filter (where weather_match_status = 'matched') as matched_flights,
    round(
        100.0 * count(*) filter (where weather_match_status = 'matched') / nullif(count(*), 0),
        2
    ) as match_pct
from {{ ref('int_flights__weather_at_departure') }}
group by origin, year_month
order by origin, year_month
