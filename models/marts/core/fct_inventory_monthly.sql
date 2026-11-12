-- Grain: one product in one store for one month (periodic snapshot).
-- Stock-on-hand and stockout days are semi-additive: sum across stores and products,
-- never across months.
with stock as (
    select
        *,
        last_day(month_start)                                      as month_end,
        day(last_day(month_start))                                 as days_in_month
    from {{ ref('stg_inventory__stock') }}
),

sold as (
    select
        st.store_code,
        pr.sku,
        d.month_start,
        sum(f.quantity)            as units_sold,
        sum(f.net_amount_excl_gst) as net_sales_excl_gst
    from {{ ref('fct_sales') }}       as f
    join {{ ref('dim_date') }}        as d  on f.date_key = d.date_key
    join {{ ref('dim_store') }}       as st on f.store_key = st.store_key
    join {{ ref('dim_product') }}     as pr on f.product_key = pr.product_key
    group by all
)

select
    {{ surrogate_key(['stock.store_code', 'stock.sku', 'stock.month_start']) }} as inventory_key,
    cast(strftime(stock.month_end, '%Y%m%d') as integer)           as date_key,
    {{ surrogate_key(['stock.store_code']) }}                      as store_key,
    p.product_key,
    {{ surrogate_key(['p.supplier_code']) }}                       as supplier_key,
    stock.month_start,
    stock.on_hand_qty,
    stock.received_qty,
    coalesce(sold.units_sold, 0)                                   as units_sold,
    coalesce(sold.net_sales_excl_gst, 0)                           as net_sales_excl_gst,
    stock.on_hand_qty * p.standard_cost                            as inventory_value,
    stock.days_in_month,
    stock.stockout_days,
    stock.stockout_days > 0                                        as had_stockout,
    -- sales rate on the days the shelf was full, applied to the days it was empty
    round(coalesce(sold.net_sales_excl_gst, 0)
          / (stock.days_in_month - stock.stockout_days) * stock.stockout_days, 2)
                                                                   as estimated_lost_sales
from stock
left join {{ ref('dim_product') }} as p
    on  stock.sku = p.sku
    and stock.month_end between p.valid_from and p.valid_to
left join sold
    on  stock.store_code = sold.store_code
    and stock.sku = sold.sku
    and stock.month_start = sold.month_start
