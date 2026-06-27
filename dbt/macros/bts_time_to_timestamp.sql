{#-
  Normalize BTS HHMM to a 4-digit string (e.g. 800 -> 0800, 1530 -> 1530).
  Strips trailing .0 from numeric casts and left-pads with zeros.
-#}
{% macro bts_hhmm_string(time_value) -%}
lpad(
    regexp_replace(trim(coalesce({{ time_value }}::text, '')), '\.0+$', ''),
    4,
    '0'
)
{%- endmacro %}


{#-
  Convert BTS FlightDate + local HHMM to a timestamp without time zone (wall clock).

  Rules:
  - NULL/empty time -> NULL
  - 800 -> 08:00 on flight_date
  - 1530 -> 15:30 on flight_date
  - 1 -> 00:01 on flight_date
  - 2400 -> 00:00 on flight_date + 1 day (BTS end-of-day midnight convention)
  - Invalid hour/minute -> NULL
-#}
{% macro bts_time_to_timestamp(flight_date, time_value) -%}
case
    when {{ flight_date }} is null then null
    when trim(coalesce({{ time_value }}::text, '')) in ('', 'NA') then null
    when substring({{ bts_hhmm_string(time_value) }} from 1 for 2)::integer = 24
         and substring({{ bts_hhmm_string(time_value) }} from 3 for 2)::integer = 0
        then ({{ flight_date }} + interval '1 day')::timestamp
    when substring({{ bts_hhmm_string(time_value) }} from 1 for 2)::integer > 23
         or substring({{ bts_hhmm_string(time_value) }} from 3 for 2)::integer > 59
        then null
    else (
        {{ flight_date }}
        + make_interval(
            hours => substring({{ bts_hhmm_string(time_value) }} from 1 for 2)::integer,
            mins => substring({{ bts_hhmm_string(time_value) }} from 3 for 2)::integer
          )
    )::timestamp
end
{%- endmacro %}


{#-
  Convert BTS FlightDate + local HHMM in an IANA timezone to UTC timestamptz.
  timezone_expr should be a quoted IANA string or column reference.
-#}
{% macro bts_time_to_utc(flight_date, time_value, timezone_expr) -%}
(
    {{ bts_time_to_timestamp(flight_date, time_value) }}
    at time zone {{ timezone_expr }}
)::timestamptz
{%- endmacro %}
