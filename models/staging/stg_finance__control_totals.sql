select
    store_code,
    quarter                                          as quarter_label,
    cast(net_sales_excl_gst as decimal(14, 2))       as control_net_sales_excl_gst
from {{ source('finance', 'control_totals') }}
