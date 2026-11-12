select
    {{ surrogate_key(['store_code']) }}    as store_key,
    store_code,
    store_name,
    suburb,
    city,
    region,
    island,
    pos_system,
    opened_on,
    floor_area_m2
from {{ ref('stg_reference__stores') }}
