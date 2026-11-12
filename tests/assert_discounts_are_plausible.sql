-- A rebuilt discount outside 0-45% of gross means a price-list version or GST conversion
-- was applied wrongly (one cent of rounding tolerance).
select sales_key, gross_amount_excl_gst, discount_amount_excl_gst
from {{ ref('fct_sales') }}
where discount_amount_excl_gst / gross_amount_excl_gst < -0.001
   or discount_amount_excl_gst / gross_amount_excl_gst > 0.45
