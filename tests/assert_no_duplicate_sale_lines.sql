-- After de-duplication a product appears at most once on a transaction.
select f.transaction_id, p.sku, count(*) as copies
from {{ ref('fct_sales') }} as f
join {{ ref('dim_product') }} as p on f.product_key = p.product_key
group by all
having count(*) > 1
