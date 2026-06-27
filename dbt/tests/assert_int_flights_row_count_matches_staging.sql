-- int_flights__departure_context should have same row count as staging
select
    (select count(*) from {{ ref('stg_bts__flights') }}) as staging_rows,
    (select count(*) from {{ ref('int_flights__departure_context') }}) as intermediate_rows
where (select count(*) from {{ ref('stg_bts__flights') }})
    <> (select count(*) from {{ ref('int_flights__departure_context') }})
