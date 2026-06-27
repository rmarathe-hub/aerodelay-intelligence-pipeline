-- Fail if any flight origin is missing from dim_airports
select distinct f.origin as airport_code
from {{ ref('stg_bts__flights') }} as f
left join {{ ref('dim_airports') }} as a on f.origin = a.airport_code
where a.airport_code is null
