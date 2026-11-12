-- POS C: spreadsheet exports. Product is free text, the only amount is a GST-inclusive
-- line total, refunds are negative, and some weeks were exported twice.
with source as (
    select * from {{ source('pos_c', 'sales') }}
),

typed as (
    select
        {{ store_from_filename() }}                               as store_code,
        invoice_ref                                               as local_transaction_id,
        strptime(sale_date, '%d-%b-%y')::date                     as sale_date,
        lower(trim(regexp_replace(product, '\s+', ' ', 'g')))     as product_name_clean,
        cast(quantity as integer)                                 as quantity_signed,
        cast(line_total_incl_gst as decimal(12, 2))               as line_total_incl_gst,
        {{ customer_id('customer_email') }}                       as customer_id,
        nullif(account_type, '')                                  as account_type,
        -- a row repeated in every column is a double export, not a second sale
        row_number() over (
            partition by {{ store_from_filename() }}, invoice_ref, sale_date, product,
                         quantity, line_total_incl_gst, customer_email
            order by filename
        )                                                         as copy_number
    from source
)

select
    typed.store_code,
    'pos_c'                                                       as source_system,
    typed.local_transaction_id,
    row_number() over (
        partition by typed.store_code, typed.local_transaction_id order by catalogue.sku
    )                                                             as line_number,
    typed.sale_date,
    catalogue.sku,
    typed.product_name_clean,
    typed.customer_id,
    typed.account_type,
    typed.quantity_signed < 0                                     as is_return,
    abs(typed.quantity_signed)                                    as quantity_abs,
    cast(null as decimal(12, 2))                                  as gross_amount_excl_gst_abs,  -- list price not reported
    round(abs(typed.line_total_incl_gst) / (1 + {{ var('gst_rate') }}), 2)
                                                                  as net_amount_excl_gst_abs,
    typed.line_total_incl_gst                                     as amount_as_reported
from typed
left join {{ ref('stg_reference__products') }} as catalogue
    on typed.product_name_clean = catalogue.product_name_clean
where typed.copy_number = 1
