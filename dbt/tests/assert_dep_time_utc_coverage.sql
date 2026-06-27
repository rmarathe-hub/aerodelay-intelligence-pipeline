-- dep_time_utc should be populated for at least 99% of rows
select
    count(*) as total_rows,
    count(*) filter (where dep_time_utc is null) as null_dep_time_utc,
    round(
        100.0 * count(*) filter (where dep_time_utc is null) / nullif(count(*), 0),
        2
    ) as null_pct
from {{ ref('int_flights__departure_context') }}
having 100.0 * count(*) filter (where dep_time_utc is null) / nullif(count(*), 0) > 1.0
