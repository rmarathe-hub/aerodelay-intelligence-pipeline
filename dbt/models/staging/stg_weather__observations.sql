with source as (
    select * from {{ source('raw', 'weather_observations') }}
),

typed as (
    select
        upper({{ clean_text('station') }}) as station,
        {{ clean_text('valid') }}::timestamptz as valid_utc,
        {{ clean_numeric('tmpf') }} as temperature_f,
        {{ clean_numeric('dwpf') }} as dewpoint_f,
        {{ clean_numeric('relh') }} as relative_humidity_pct,
        {{ clean_numeric('drct') }} as wind_direction_deg,
        {{ clean_numeric('sknt') }} as wind_speed_knots,
        {{ clean_numeric_trace('p01i') }} as precip_1hr_inches,
        {{ clean_numeric('alti') }} as altimeter_inhg,
        {{ clean_numeric('mslp') }} as sea_level_pressure_hpa,
        {{ clean_numeric('vsby') }} as visibility_miles,
        {{ clean_numeric('gust') }} as wind_gust_knots,
        {{ clean_text('skyc1') }} as sky_cover_1,
        {{ clean_text('skyc2') }} as sky_cover_2,
        {{ clean_text('skyc3') }} as sky_cover_3,
        {{ clean_text('skyc4') }} as sky_cover_4,
        {{ clean_numeric('skyl1') }} as sky_layer_1_ft,
        {{ clean_numeric('skyl2') }} as sky_layer_2_ft,
        {{ clean_numeric('skyl3') }} as sky_layer_3_ft,
        {{ clean_numeric('skyl4') }} as sky_layer_4_ft,
        {{ clean_text('wxcodes') }} as weather_codes,
        {{ clean_numeric('feel') }} as feels_like_f,
        {{ clean_text('metar') }} as metar_raw,
        {{ clean_numeric('snowdepth') }} as snow_depth_inches,
        year_month,
        source_file,
        loaded_at,
        run_id
    from source
    where {{ clean_text('station') }} is not null
      and {{ clean_text('valid') }} is not null
),

deduped as (
    select
        *,
        row_number() over (
            partition by station, valid_utc
            order by loaded_at desc, source_file desc
        ) as row_num
    from typed
)

select
    station,
    valid_utc,
    temperature_f,
    dewpoint_f,
    relative_humidity_pct,
    wind_direction_deg,
    wind_speed_knots,
    precip_1hr_inches,
    altimeter_inhg,
    sea_level_pressure_hpa,
    visibility_miles,
    wind_gust_knots,
    sky_cover_1,
    sky_cover_2,
    sky_cover_3,
    sky_cover_4,
    sky_layer_1_ft,
    sky_layer_2_ft,
    sky_layer_3_ft,
    sky_layer_4_ft,
    weather_codes,
    feels_like_f,
    metar_raw,
    snow_depth_inches,
    year_month,
    source_file,
    loaded_at,
    run_id
from deduped
where row_num = 1
