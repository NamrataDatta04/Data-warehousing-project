select store_code, item_code, sku
from {{ source('reference', 'pos_b_item_map') }}
