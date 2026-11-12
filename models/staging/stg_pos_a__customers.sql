-- Names are deliberately not selected: the warehouse only needs a stable, anonymous key.
select
    {{ store_from_filename() }}            as store_code,
    cust_id                                as local_customer_ref,
    {{ customer_id('email') }}             as customer_id,
    upper(customer_type)                   as customer_type
from {{ source('pos_a', 'customers') }}
