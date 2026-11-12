-- POS A: prices are already GST-exclusive; refunds carry a flag and a positive quantity.
with source as (
    select * from {{ source('pos_a', 'sales') }}
)

select
    {{ store_from_filename() }}                                   as store_code,
    'pos_a'                                                       as source_system,
    txn_id                                                        as local_transaction_id,
    cast(line_no as integer)                                      as line_number,
    cast(cast(sold_at as timestamp) as date)                      as sale_date,
    sku,
    nullif(cust_id, '')                                           as local_customer_ref,
    is_return = 'Y'                                               as is_return,
    cast(qty as integer)                                          as quantity_abs,
    round(cast(qty as integer) * cast(unit_price_excl_gst as decimal(12, 2)), 2)
                                                                  as gross_amount_excl_gst_abs,
    round(cast(qty as integer) * cast(unit_price_excl_gst as decimal(12, 2))
          * (1 - cast(discount_pct as double) / 100), 2)          as net_amount_excl_gst_abs,
    -- what a plain spreadsheet SUM over this file would add up
    round(cast(qty as integer) * cast(unit_price_excl_gst as decimal(12, 2))
          * (1 - cast(discount_pct as double) / 100), 2)          as amount_as_reported
from source
