select
    store_code,
    sku,
    strptime(regexp_extract(filename, 'stock_([0-9]{4}-[0-9]{2})', 1) || '-01', '%Y-%m-%d')::date as month_start,
    cast(on_hand_qty as integer)           as on_hand_qty,
    cast(received_qty as integer)          as received_qty,
    cast(stockout_days as integer)         as stockout_days
from {{ source('inventory', 'stock') }}
