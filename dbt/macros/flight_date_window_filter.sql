{% macro flight_date_window_filter() %}
{% if var('dev_year_month', none) is not none %}
    {{ dev_year_month_filter() }}
{% elif var('start_date', none) is not none and var('end_date', none) is not none %}
    and flight_date >= '{{ var("start_date") }}'::date
    and flight_date < '{{ var("end_date") }}'::date
{% endif %}
{% endmacro %}
