-- Q1. Which stores are really performing?
-- Ranks every store three ways: on the figures head office has today (files stacked and
-- summed), on conformed net sales, and on net profit after operating costs.
with as_reported as (
    select store_code, sum(amount_as_reported) as sales_as_reported
    from {{ ref('int_sales_as_reported') }}
    group by store_code
),

pnl as (
    select
        store_key,
        sum(net_sales_excl_gst)        as net_sales_excl_gst,
        sum(gross_profit)              as gross_profit,
        sum(total_operating_expense)   as total_operating_expense,
        sum(rent_expense)              as rent_expense,
        sum(net_profit)                as net_profit
    from {{ ref('fct_store_pnl_quarterly') }}
    group by store_key
)

select
    s.store_code,
    s.city,
    s.region,
    s.pos_system,
    round(r.sales_as_reported)                                             as sales_as_reported,
    round(p.net_sales_excl_gst)                                            as net_sales_excl_gst,
    round(100.0 * (r.sales_as_reported / p.net_sales_excl_gst - 1), 1)     as overstated_pct,
    rank() over (order by r.sales_as_reported desc)                        as rank_as_reported,
    rank() over (order by p.net_sales_excl_gst desc)                       as rank_net_sales,
    rank() over (order by p.net_profit desc)                               as rank_net_profit,
    round(100.0 * p.gross_profit / p.net_sales_excl_gst, 1)                as gross_margin_pct,
    round(100.0 * p.rent_expense / p.net_sales_excl_gst, 1)                as rent_pct_of_sales,
    round(p.net_profit)                                                    as net_profit,
    round(100.0 * p.net_profit / p.net_sales_excl_gst, 1)                  as net_margin_pct,
    round(p.net_sales_excl_gst / s.floor_area_m2 / 2)                      as net_sales_per_m2_per_year
from {{ ref('dim_store') }} as s
join as_reported as r on s.store_code = r.store_code
join pnl         as p on s.store_key = p.store_key
order by rank_net_sales
