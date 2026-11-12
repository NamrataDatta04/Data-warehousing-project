-- Q3. Which suppliers leave shelves empty, where, and what does it cost?
select
    su.supplier_name,
    su.country,
    su.lead_time_days,
    st.island,
    round(avg(i.stockout_days), 1)                                         as avg_stockout_days_per_month,
    round(100.0 * avg(case when i.had_stockout then 1 else 0 end), 1)      as product_months_with_stockout_pct,
    round(sum(i.net_sales_excl_gst))                                       as net_sales_excl_gst,
    round(sum(i.estimated_lost_sales))                                     as estimated_lost_sales,
    round(100.0 * sum(i.estimated_lost_sales)
          / (sum(i.net_sales_excl_gst) + sum(i.estimated_lost_sales)), 1)  as lost_pct_of_potential_sales
from {{ ref('fct_inventory_monthly') }} as i
join {{ ref('dim_supplier') }} as su on i.supplier_key = su.supplier_key
join {{ ref('dim_store') }}    as st on i.store_key = st.store_key
group by all
order by estimated_lost_sales desc
