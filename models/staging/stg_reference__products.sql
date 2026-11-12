select
    sku,
    product_name,
    lower(trim(regexp_replace(product_name, '\s+', ' ', 'g'))) as product_name_clean,
    category,
    brand,
    unit_of_measure,
    supplier_code
from {{ source('reference', 'product_catalogue') }}
