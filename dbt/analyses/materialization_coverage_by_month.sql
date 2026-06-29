-- Weather match coverage by calendar month (year_month on flight grain).
select
    year_month,
    count(*) as flights,
    count(*) filter (where weather_match_status = 'matched') as matched_flights,
    round(
        100.0 * count(*) filter (where weather_match_status = 'matched') / nullif(count(*), 0),
        2
    ) as match_pct
from {{ ref('int_flights__weather_at_departure') }}
group by year_month
order by year_month
