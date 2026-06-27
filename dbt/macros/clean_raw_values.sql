{% macro clean_text(value_expr) -%}
    nullif(nullif(trim({{ value_expr }}::text), ''), '{{ var("missing_token") }}')
{%- endmacro %}


{% macro clean_numeric(value_expr) -%}
    case
        when trim({{ value_expr }}::text) in ('', '{{ var("missing_token") }}') then null
        else trim({{ value_expr }}::text)::numeric
    end
{%- endmacro %}


{% macro clean_numeric_trace(value_expr) -%}
    case
        when trim({{ value_expr }}::text) in ('', '{{ var("missing_token") }}') then null
        when trim({{ value_expr }}::text) = '{{ var("trace_token") }}' then 0
        else trim({{ value_expr }}::text)::numeric
    end
{%- endmacro %}


{% macro clean_flag(value_expr) -%}
    coalesce(nullif(trim({{ value_expr }}::text), ''), '0')::numeric = 1
{%- endmacro %}
