-- The quarterly profit and loss must add up to exactly the same revenue as the sales fact.
select 'revenue mismatch' as problem, pnl.total, sales.total
from (select sum(net_sales_excl_gst) as total from {{ ref('fct_store_pnl_quarterly') }}) as pnl
cross join (select sum(net_amount_excl_gst) as total from {{ ref('fct_sales') }}) as sales
where abs(pnl.total - sales.total) > 0.01
