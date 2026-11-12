-- Every store-quarter in the warehouse must agree with the finance team's control total
-- to within 0.05% (the stores round GST-inclusive prices to the cent, so a few cents of
-- drift per thousand lines is expected). Returns the store-quarters that do not.
with warehouse as (
    select s.store_code, d.quarter_label, sum(f.net_amount_excl_gst) as net_sales
    from {{ ref('fct_sales') }} as f
    join {{ ref('dim_store') }} as s on f.store_key = s.store_key
    join {{ ref('dim_date') }}  as d on f.date_key = d.date_key
    group by all
)

select
    c.store_code,
    c.quarter_label,
    c.control_net_sales_excl_gst,
    w.net_sales
from {{ ref('stg_finance__control_totals') }} as c
left join warehouse as w
    on c.store_code = w.store_code and c.quarter_label = w.quarter_label
where w.net_sales is null
   or abs(w.net_sales - c.control_net_sales_excl_gst) > 0.0005 * c.control_net_sales_excl_gst
