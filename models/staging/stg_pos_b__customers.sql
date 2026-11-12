select
    {{ store_from_filename() }}            as store_code,
    "Cust Ref"                             as local_customer_ref,
    {{ customer_id('"Email"') }}           as customer_id,
    case when "Account Type" = 'TRADE ACCOUNT' then 'TRADE' else 'RETAIL' end as customer_type
from {{ source('pos_b', 'customers') }}
