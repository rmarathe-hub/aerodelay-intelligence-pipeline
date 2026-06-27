-- int_flights__weather_at_departure should have same row count as departure context
select
    (select count(*) from {{ ref('int_flights__departure_context') }}) as departure_context_rows,
    (select count(*) from {{ ref('int_flights__weather_at_departure') }}) as weather_join_rows
where (select count(*) from {{ ref('int_flights__departure_context') }})
    <> (select count(*) from {{ ref('int_flights__weather_at_departure') }})
