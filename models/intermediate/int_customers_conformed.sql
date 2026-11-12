-- One row per person across the co-op. The same shopper has a different local number in
-- every store (and the same number can belong to different people), so identity is the
-- hashed email, never the store's own customer number.
with purchases as (
    select customer_id, store_code, reported_customer_type, sale_date, transaction_id, net_amount_excl_gst
    from {{ ref('int_sales_conformed') }}
    where customer_id is not null
),

by_store as (
    select
        customer_id,
        store_code,
        count(distinct transaction_id) as transactions,
        row_number() over (
            partition by customer_id order by count(distinct transaction_id) desc, store_code
        ) as store_rank
    from purchases
    group by customer_id, store_code
)

select
    p.customer_id,
    -- a customer with a trade account anywhere is a trade customer everywhere
    case when bool_or(p.reported_customer_type = 'TRADE') then 'TRADE' else 'RETAIL' end as customer_type,
    min(p.sale_date)                                   as first_purchase_date,
    max(p.sale_date)                                   as last_purchase_date,
    count(distinct p.store_code)                       as stores_shopped,
    max(case when b.store_rank = 1 then b.store_code end) as home_store_code
from purchases as p
join by_store as b
    on p.customer_id = b.customer_id and p.store_code = b.store_code
group by p.customer_id
