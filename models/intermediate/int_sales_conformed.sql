-- One row per sale line, in one shape, for all twelve stores:
-- signed quantities and GST-exclusive dollars, a co-op-wide customer id, a head-office SKU.
with pos_a as (
    select
        s.store_code, s.source_system, s.local_transaction_id, s.line_number, s.sale_date, s.sku,
        c.customer_id, c.customer_type as reported_customer_type,
        s.is_return, s.quantity_abs, s.gross_amount_excl_gst_abs, s.net_amount_excl_gst_abs
    from {{ ref('stg_pos_a__sales') }} as s
    left join {{ ref('stg_pos_a__customers') }} as c
        on s.store_code = c.store_code and s.local_customer_ref = c.local_customer_ref
),

pos_b as (
    select
        s.store_code, s.source_system, s.local_transaction_id, s.line_number, s.sale_date, s.sku,
        c.customer_id, c.customer_type as reported_customer_type,
        s.is_return, s.quantity_abs, s.gross_amount_excl_gst_abs, s.net_amount_excl_gst_abs
    from {{ ref('stg_pos_b__sales') }} as s
    left join {{ ref('stg_pos_b__customers') }} as c
        on s.store_code = c.store_code and s.local_customer_ref = c.local_customer_ref
),

pos_c as (
    select
        store_code, source_system, local_transaction_id, line_number, sale_date, sku,
        customer_id,
        case account_type when 'Trade' then 'TRADE' when 'Cash' then 'RETAIL' end as reported_customer_type,
        is_return, quantity_abs, gross_amount_excl_gst_abs, net_amount_excl_gst_abs
    from {{ ref('stg_pos_c__sales') }}
),

unioned as (
    select * from pos_a
    union all
    select * from pos_b
    union all
    select * from pos_c
)

select
    -- receipt numbers restart in every store, so the store is part of the transaction id
    case when source_system = 'pos_c' then local_transaction_id      -- already prefixed
         else store_code || '-' || local_transaction_id end              as transaction_id,
    line_number,
    store_code,
    source_system,
    sale_date,
    sku,
    customer_id,
    reported_customer_type,
    is_return,
    case when is_return then -1 else 1 end * quantity_abs               as quantity,
    case when is_return then -1 else 1 end * gross_amount_excl_gst_abs  as reported_gross_amount_excl_gst,
    case when is_return then -1 else 1 end * net_amount_excl_gst_abs    as net_amount_excl_gst
from unioned
