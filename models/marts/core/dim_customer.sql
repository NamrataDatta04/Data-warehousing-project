-- Holds no name, email or address: the natural key is a one-way hash of the email.
-- Unidentified walk-in sales point at the 'UNKNOWN' row so fact joins never drop rows.
select
    {{ surrogate_key(['customer_id']) }}   as customer_key,
    customer_id,
    customer_type,
    first_purchase_date,
    last_purchase_date,
    home_store_code,
    stores_shopped,
    stores_shopped > 1                     as is_multi_store
from {{ ref('int_customers_conformed') }}

union all

select
    {{ surrogate_key(["'UNKNOWN'"]) }}, 'UNKNOWN', 'WALK-IN', null, null, null, 0, false
