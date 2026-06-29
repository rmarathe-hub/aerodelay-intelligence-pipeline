{% macro dep_time_utc_window_filter(column_name='dep_time_utc') %}
{% if var('start_date', none) is not none and var('end_date', none) is not none %}
    and {{ column_name }} >= '{{ var("start_date") }}'::timestamptz
    and {{ column_name }} < '{{ var("end_date") }}'::timestamptz
{% endif %}
{% endmacro %}
