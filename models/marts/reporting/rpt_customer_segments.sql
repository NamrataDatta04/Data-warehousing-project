-- Q4a. Who buys? Trade accounts, identified retail customers and anonymous walk-ins.
with per_customer as (
    select
        c.customer_type,
        c.customer_key,
        c.is_multi_store,
        count(distinct f.transaction_id)   as transactions,
        sum(f.net_amount_excl_gst)         as net_sales,
        sum(f.gross_profit_amount)         as gross_profit
    from {{ ref('fct_sales') }}    as f
    join {{ ref('dim_customer') }} as c on f.customer_key = c.customer_key
    group by all
)

select
    customer_type,
    case when customer_type = 'WALK-IN' then null else count(*) end                    as customers,
    round(100.0 * sum(net_sales) / sum(sum(net_sales)) over (), 1)                     as share_of_net_sales_pct,
    round(sum(net_sales))                                                              as net_sales_excl_gst,
    round(100.0 * sum(gross_profit) / sum(net_sales), 1)                               as gross_margin_pct,
    case when customer_type = 'WALK-IN' then null else round(sum(net_sales) / count(*)) end
                                                                                       as net_sales_per_customer,
    round(sum(net_sales) / sum(transactions), 2)                                       as average_basket,
    sum(case when is_multi_store then 1 else 0 end)                                    as customers_buying_at_several_stores,
    round(sum(case when is_multi_store then net_sales else 0 end))                     as net_sales_from_multi_store_customers
from per_customer
group by customer_type
order by net_sales_excl_gst desc
