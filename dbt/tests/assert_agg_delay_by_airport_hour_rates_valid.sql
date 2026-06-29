-- delay_rate_15 must be a valid proportion; delayed flights cannot exceed total flights
select
    origin,
    dep_hour_utc,
    flight_count,
    delayed_count,
    delay_rate_15
from {{ ref('agg_delay_by_airport_hour') }}
where flight_count <= 0
    or delayed_count < 0
    or delayed_count > flight_count
    or delay_rate_15 < 0
    or delay_rate_15 > 1
