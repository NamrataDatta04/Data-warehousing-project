-- Island > region > store subtotals in one result set, using GROUP BY ROLLUP.
with rolled_up as (
    select
        s.island,
        s.region,
        s.store_code,
        grouping(s.island)                                                       as is_island_total,
        grouping(s.region)                                                       as is_region_total,
        grouping(s.store_code)                                                   as is_store_total,
        count(distinct f.transaction_id)                                         as transactions,
        sum(f.net_amount_excl_gst)                                               as net_sales,
        sum(f.gst_amount)                                                        as gst_collected,
        sum(f.gross_profit_amount)                                               as gross_profit
    from {{ ref('fct_sales') }} as f
    join {{ ref('dim_store') }} as s on f.store_key = s.store_key
    group by rollup (s.island, s.region, s.store_code)
)

select
    case when is_island_total = 1 then 'All stores' else island end              as island,
    case when is_region_total = 1 then 'Subtotal' else region end                as region,
    case when is_store_total = 1 then 'Subtotal' else store_code end             as store_code,
    is_island_total + is_region_total + is_store_total                           as rollup_level,
    transactions,
    round(net_sales)                                                             as net_sales_excl_gst,
    round(gst_collected)                                                         as gst_collected,
    round(100.0 * gross_profit / net_sales, 1)                                   as gross_margin_pct,
    round(net_sales / transactions, 2)                                           as average_basket
from rolled_up
order by is_island_total, rolled_up.island, is_region_total, rolled_up.region, is_store_total, rolled_up.store_code
