-- Island > region > store subtotals in one result set, using GROUP BY ROLLUP.
select
    case when grouping(s.island) = 1 then 'All stores' else s.island end         as island,
    case when grouping(s.region) = 1 then 'Subtotal' else s.region end           as region,
    case when grouping(s.store_code) = 1 then 'Subtotal' else s.store_code end   as store_code,
    grouping(s.island) + grouping(s.region) + grouping(s.store_code)             as rollup_level,
    count(distinct f.transaction_id)                                             as transactions,
    round(sum(f.net_amount_excl_gst))                                            as net_sales_excl_gst,
    round(sum(f.gst_amount))                                                     as gst_collected,
    round(100.0 * sum(f.gross_profit_amount) / sum(f.net_amount_excl_gst), 1)    as gross_margin_pct,
    round(sum(f.net_amount_excl_gst) / count(distinct f.transaction_id), 2)      as average_basket
from {{ ref('fct_sales') }} as f
join {{ ref('dim_store') }} as s on f.store_key = s.store_key
group by rollup (s.island, s.region, s.store_code)
order by grouping(s.island), s.island, grouping(s.region), s.region, grouping(s.store_code), s.store_code
