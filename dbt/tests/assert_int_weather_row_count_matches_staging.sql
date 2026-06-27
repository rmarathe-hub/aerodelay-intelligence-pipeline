-- int_weather__observations_enriched should have same row count as staging (1:1 station map)
select
    (select count(*) from {{ ref('stg_weather__observations') }}) as staging_rows,
    (select count(*) from {{ ref('int_weather__observations_enriched') }}) as intermediate_rows
where (select count(*) from {{ ref('stg_weather__observations') }})
    <> (select count(*) from {{ ref('int_weather__observations_enriched') }})
