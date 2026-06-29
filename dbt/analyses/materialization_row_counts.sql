-- Total rows and duplicate flight keys after full materialization.
select
    count(*) as int_rows,
    count(distinct flight_id) as distinct_flight_ids,
    count(*) - count(distinct flight_id) as duplicate_flight_keys
from {{ ref('int_flights__weather_at_departure') }}
