select
    sku,
    product_name,
    lower(trim({{ collapse_spaces('product_name') }})) as product_name_clean,
    category,
    brand,
    unit_of_measure,
    supplier_code
from {{ source('reference', 'product_catalogue') }}
