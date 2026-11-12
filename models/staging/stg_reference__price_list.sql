select
    sku,
    cast(effective_from as date)                    as effective_from,
    cast(list_price_excl_gst as decimal(12, 2))     as list_price_excl_gst,
    cast(standard_cost as decimal(12, 2))           as standard_cost
from {{ source('reference', 'price_list') }}
