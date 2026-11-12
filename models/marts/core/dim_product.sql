-- Slowly changing dimension, type 2: a new row each time the head-office price list
-- changes a product's list price or standard cost. Facts join to the version in force
-- on the day of the sale, so historical margin is not restated when prices move.
with versions as (
    select
        sku,
        effective_from                                             as valid_from,
        lead(effective_from) over (partition by sku order by effective_from) as next_effective_from,
        list_price_excl_gst,
        standard_cost
    from {{ ref('stg_reference__price_list') }}
)

select
    {{ surrogate_key(['v.sku', 'v.valid_from']) }}                 as product_key,
    v.sku,
    p.product_name,
    p.category,
    p.brand,
    p.unit_of_measure,
    p.supplier_code,
    v.list_price_excl_gst,
    v.standard_cost,
    v.valid_from,
    coalesce(v.next_effective_from - 1, date '9999-12-31')         as valid_to,
    v.next_effective_from is null                                  as is_current
from versions as v
join {{ ref('stg_reference__products') }} as p
    on v.sku = p.sku
