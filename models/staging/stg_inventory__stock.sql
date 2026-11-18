select
    store_code,
    sku,
    {{ parse_date(regex_group('filename', 'stock_([0-9]{4}-[0-9]{2})') ~ " || '-01'", 'YYYY-MM-DD') }} as month_start,
    cast(on_hand_qty as integer)           as on_hand_qty,
    cast(received_qty as integer)          as received_qty,
    cast(stockout_days as integer)         as stockout_days
from {{ source('inventory', 'stock') }}
