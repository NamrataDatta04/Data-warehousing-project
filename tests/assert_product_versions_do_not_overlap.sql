-- A product must have exactly one price-list version in force on any day.
select a.sku, a.valid_from, b.valid_from as overlapping_valid_from
from {{ ref('dim_product') }} as a
join {{ ref('dim_product') }} as b
    on  a.sku = b.sku
    and a.product_key <> b.product_key
    and a.valid_from between b.valid_from and b.valid_to

union all

select sku, null, null
from {{ ref('dim_product') }}
group by sku
having sum(case when is_current then 1 else 0 end) <> 1
