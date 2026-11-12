-- Q5. What did supplier cost increases do to margin?
-- Uses the type 2 product dimension: each sale is costed at the version in force that day,
-- so margin before and after a price-list change can be compared directly.
with sales_by_version as (
    select
        p.category,
        p.valid_from                       as price_list_from,
        sum(f.net_amount_excl_gst)         as net_sales,
        sum(f.gross_profit_amount)         as gross_profit
    from {{ ref('fct_sales') }}   as f
    join {{ ref('dim_product') }} as p on f.product_key = p.product_key
    group by all
),

price_list_by_version as (
    select
        category,
        valid_from                         as price_list_from,
        sum(standard_cost)                 as total_standard_cost,
        sum(list_price_excl_gst)           as total_list_price
    from {{ ref('dim_product') }}
    group by all
)

select
    s.category,
    s.price_list_from,
    round(s.net_sales)                                                  as net_sales_excl_gst,
    round(100.0 * s.gross_profit / s.net_sales, 1)                      as gross_margin_pct,
    round(100.0 * (l.total_standard_cost / lag(l.total_standard_cost) over w - 1), 1) as cost_change_pct,
    round(100.0 * (l.total_list_price / lag(l.total_list_price) over w - 1), 1)       as list_price_change_pct,
    round(100.0 * s.gross_profit / s.net_sales
          - lag(100.0 * s.gross_profit / s.net_sales) over w, 1)        as margin_change_points,
    -- gross profit the later period would have earned at the earlier margin
    round((lag(s.gross_profit / s.net_sales) over w - s.gross_profit / s.net_sales) * s.net_sales)
                                                                        as gross_profit_lost_to_squeeze
from sales_by_version as s
join price_list_by_version as l
    on s.category = l.category and s.price_list_from = l.price_list_from
window w as (partition by s.category order by s.price_list_from)
order by s.category, s.price_list_from
