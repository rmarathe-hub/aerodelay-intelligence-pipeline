{% macro dev_year_month_filter(column_name='year_month') %}
{% if var('dev_year_month', none) is not none %}
    and {{ column_name }} = '{{ var('dev_year_month') }}'
{% endif %}
{% endmacro %}
