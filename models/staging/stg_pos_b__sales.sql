-- POS B: prices and discounts include GST, items use store-local codes, refunds are a row type.
with source as (
    select * from {{ source('pos_b', 'sales') }}
),

typed as (
    select
        {{ store_from_filename() }}                               as store_code,
        "Receipt No"                                              as local_transaction_id,
        strptime("Date", '%d/%m/%Y')::date                        as sale_date,
        "Item Code"                                               as item_code,
        nullif("Cust Ref", '')                                    as local_customer_ref,
        "Type" = 'REFUND'                                         as is_return,
        cast("Qty" as integer)                                    as quantity_abs,
        cast("Price Inc GST" as decimal(12, 2))                   as price_incl_gst,
        cast("Disc $" as decimal(12, 2))                          as discount_incl_gst
    from source
)

select
    typed.store_code,
    'pos_b'                                                       as source_system,
    typed.local_transaction_id,
    row_number() over (
        partition by typed.store_code, typed.local_transaction_id order by typed.item_code
    )                                                             as line_number,
    typed.sale_date,
    item_map.sku,
    typed.item_code,
    typed.local_customer_ref,
    typed.is_return,
    typed.quantity_abs,
    round(typed.quantity_abs * typed.price_incl_gst / (1 + {{ var('gst_rate') }}), 2)
                                                                  as gross_amount_excl_gst_abs,
    round((typed.quantity_abs * typed.price_incl_gst - typed.discount_incl_gst)
          / (1 + {{ var('gst_rate') }}), 2)                       as net_amount_excl_gst_abs,
    typed.quantity_abs * typed.price_incl_gst - typed.discount_incl_gst
                                                                  as amount_as_reported
from typed
left join {{ ref('stg_reference__pos_b_item_map') }} as item_map
    on  typed.store_code = item_map.store_code
    and typed.item_code  = item_map.item_code
