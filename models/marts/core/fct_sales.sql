-- Grain: one product on one transaction in one store. Refund lines are negative.
-- All dollar amounts exclude GST; GST is carried separately.
with sales as (
    select * from {{ ref('int_sales_conformed') }}
)

select
    {{ surrogate_key(['s.transaction_id', 's.line_number']) }}          as sales_key,
    cast(strftime(s.sale_date, '%Y%m%d') as integer)                    as date_key,
    {{ surrogate_key(['s.store_code']) }}                               as store_key,
    p.product_key,
    {{ surrogate_key(["coalesce(s.customer_id, 'UNKNOWN')"]) }}         as customer_key,
    {{ surrogate_key(['p.supplier_code']) }}                            as supplier_key,
    s.transaction_id,
    s.line_number,
    s.source_system,
    s.is_return,
    s.quantity,
    -- spreadsheet stores do not report the list price, so gross is rebuilt from the price list
    coalesce(s.reported_gross_amount_excl_gst, s.quantity * p.list_price_excl_gst)
                                                                        as gross_amount_excl_gst,
    coalesce(s.reported_gross_amount_excl_gst, s.quantity * p.list_price_excl_gst)
        - s.net_amount_excl_gst                                         as discount_amount_excl_gst,
    s.net_amount_excl_gst,
    round(s.net_amount_excl_gst * {{ var('gst_rate') }}, 2)             as gst_amount,
    s.quantity * p.standard_cost                                        as cost_amount,
    s.net_amount_excl_gst - s.quantity * p.standard_cost                as gross_profit_amount
from sales as s
left join {{ ref('dim_product') }} as p
    on  s.sku = p.sku
    and s.sale_date between p.valid_from and p.valid_to
