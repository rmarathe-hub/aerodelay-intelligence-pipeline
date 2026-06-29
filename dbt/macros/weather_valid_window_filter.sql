{% macro weather_valid_window_filter() %}
{% if var('dev_year_month', none) is not none %}
    {{ dev_year_month_filter() }}
{% elif var('start_date', none) is not none and var('end_date', none) is not none %}
{% set window_hours = var('weather_join_window_hours') %}
    and valid_utc >= '{{ var("start_date") }}'::timestamptz - interval '{{ window_hours }} hours'
    and valid_utc < '{{ var("end_date") }}'::timestamptz + interval '{{ window_hours }} hours'
{% endif %}
{% endmacro %}
