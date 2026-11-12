select
    {{ surrogate_key(['supplier_code']) }} as supplier_key,
    supplier_code,
    supplier_name,
    country,
    is_imported,
    lead_time_days
from {{ ref('stg_reference__suppliers') }}
