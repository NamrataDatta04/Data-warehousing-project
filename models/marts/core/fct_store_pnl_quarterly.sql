-- Grain: one store for one quarter. Revenue and cost of goods come from the sales fact,
-- operating costs from finance, so the profit and loss always agrees with line-level sales.
with trading as (
    select
        f.store_key,
        d.quarter_label,
        d.quarter_start,
        count(distinct f.transaction_id)   as transaction_count,
        sum(f.net_amount_excl_gst)         as net_sales_excl_gst,
        sum(f.cost_amount)                 as cost_of_goods_sold,
        sum(f.gross_profit_amount)         as gross_profit
    from {{ ref('fct_sales') }} as f
    join {{ ref('dim_date') }}  as d on f.date_key = d.date_key
    group by all
)

select
    {{ surrogate_key(['o.store_code', 'o.quarter_label']) }}       as store_pnl_key,
    cast(strftime(o.quarter_start, '%Y%m%d') as integer)           as date_key,
    s.store_key,
    o.quarter_label,
    t.transaction_count,
    t.net_sales_excl_gst,
    t.cost_of_goods_sold,
    t.gross_profit,
    o.rent_expense,
    o.wages_expense,
    o.utilities_expense,
    o.marketing_expense,
    o.other_expense,
    o.rent_expense + o.wages_expense + o.utilities_expense + o.marketing_expense + o.other_expense
                                                                   as total_operating_expense,
    t.gross_profit - (o.rent_expense + o.wages_expense + o.utilities_expense
                      + o.marketing_expense + o.other_expense)     as net_profit
from {{ ref('stg_finance__opex_quarterly') }} as o
join {{ ref('dim_store') }} as s
    on o.store_code = s.store_code
left join trading as t
    on s.store_key = t.store_key and o.quarter_label = t.quarter_label
