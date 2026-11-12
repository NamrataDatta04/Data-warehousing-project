select
    supplier_code,
    supplier_name,
    country,
    country <> 'New Zealand'               as is_imported,
    cast(lead_time_days as integer)        as lead_time_days
from {{ source('reference', 'suppliers') }}
