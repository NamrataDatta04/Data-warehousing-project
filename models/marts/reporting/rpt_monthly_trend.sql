-- Co-op monthly sales with a three-month moving average and growth on the same month last year.
with monthly as (
    select
        d.month_start,
        d.nz_financial_year,
        d.season,
        sum(f.net_amount_excl_gst)                                      as net_sales,
        sum(f.gross_profit_amount)                                      as gross_profit,
        sum(case when p.category = 'Garden' then f.net_amount_excl_gst else 0 end) as garden_net_sales
    from {{ ref('fct_sales') }}   as f
    join {{ ref('dim_date') }}    as d on f.date_key = d.date_key
    join {{ ref('dim_product') }} as p on f.product_key = p.product_key
    group by all
)

select
    month_start,
    nz_financial_year,
    season,
    round(net_sales)                                                    as net_sales_excl_gst,
    round(avg(net_sales) over (order by month_start rows between 2 preceding and current row))
                                                                        as moving_average_3_months,
    round(100.0 * (net_sales / lag(net_sales, 12) over (order by month_start) - 1), 1)
                                                                        as growth_on_last_year_pct,
    round(100.0 * gross_profit / net_sales, 1)                          as gross_margin_pct,
    round(100.0 * garden_net_sales / net_sales, 1)                      as garden_share_pct
from monthly
order by month_start
