-- fct_flights should have same row count as the weather join model
select
    (select count(*) from {{ ref('int_flights__weather_at_departure') }}) as weather_join_rows,
    (select count(*) from {{ ref('fct_flights') }}) as fact_rows
where (select count(*) from {{ ref('int_flights__weather_at_departure') }})
    <> (select count(*) from {{ ref('fct_flights') }})
