select
    reporting_airline,
    origin,
    dest,
    flight_count,
    delayed_count,
    delay_rate_15
from {{ ref('agg_delay_by_carrier_route') }}
where flight_count <= 0
    or delayed_count < 0
    or delayed_count > flight_count
    or delay_rate_15 < 0
    or delay_rate_15 > 1
