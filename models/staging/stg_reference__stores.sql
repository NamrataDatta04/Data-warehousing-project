select
    store_code,
    store_name,
    suburb,
    city,
    region,
    island || ' Island'                    as island,
    pos_system,
    cast(opened_on as date)                as opened_on,
    cast(floor_area_m2 as integer)         as floor_area_m2
from {{ source('reference', 'stores') }}
