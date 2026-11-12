-- Q4b. Do customers come back? Quarterly cohorts by first purchase, for identified customers.
with activity as (
    select distinct
        c.customer_key,
        c.customer_type,
        date_trunc('quarter', c.first_purchase_date)::date as cohort_quarter,
        d.quarter_start                                    as active_quarter
    from {{ ref('fct_sales') }}    as f
    join {{ ref('dim_customer') }} as c on f.customer_key = c.customer_key
    join {{ ref('dim_date') }}     as d on f.date_key = d.date_key
    where c.customer_type <> 'WALK-IN'
),

counted as (
    select
        customer_type,
        cohort_quarter,
        date_diff('quarter', cohort_quarter, active_quarter) as quarters_since_first_purchase,
        count(*)                                             as active_customers
    from activity
    group by all
)

select
    customer_type,
    cohort_quarter,
    quarters_since_first_purchase,
    active_customers,
    first_value(active_customers) over cohort                              as cohort_size,
    round(100.0 * active_customers / first_value(active_customers) over cohort, 1) as retention_pct
from counted
window cohort as (partition by customer_type, cohort_quarter order by quarters_since_first_purchase)
order by customer_type, cohort_quarter, quarters_since_first_purchase
