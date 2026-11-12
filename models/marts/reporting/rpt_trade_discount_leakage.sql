-- Q2. Where is margin leaking through trade discounts?
-- Compares each store's average trade discount with the co-op median and prices the gap.
with trade as (
    select
        f.store_key,
        sum(f.gross_amount_excl_gst)       as trade_gross_sales,
        sum(f.discount_amount_excl_gst)    as trade_discount,
        sum(f.net_amount_excl_gst)         as trade_net_sales,
        sum(f.gross_profit_amount)         as trade_gross_profit
    from {{ ref('fct_sales') }}    as f
    join {{ ref('dim_customer') }} as c on f.customer_key = c.customer_key
    where c.customer_type = 'TRADE'
    group by f.store_key
),

rates as (
    select
        *,
        trade_discount / trade_gross_sales                                  as discount_rate,
        median(trade_discount / trade_gross_sales) over ()                  as coop_median_rate
    from trade
)

select
    s.store_code,
    s.city,
    round(r.trade_net_sales)                                                as trade_net_sales,
    round(100.0 * r.discount_rate, 1)                                       as trade_discount_pct,
    round(100.0 * r.coop_median_rate, 1)                                    as coop_median_discount_pct,
    round(100.0 * r.trade_gross_profit / r.trade_net_sales, 1)              as trade_gross_margin_pct,
    -- dollars given away above the co-op's normal trade terms, over the two years
    round(greatest(r.discount_rate - r.coop_median_rate, 0) * r.trade_gross_sales)
                                                                            as discount_above_median,
    rank() over (order by r.discount_rate desc)                             as discount_rank
from rates as r
join {{ ref('dim_store') }} as s on r.store_key = s.store_key
order by discount_rank
