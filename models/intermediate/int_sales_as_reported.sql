-- The "before" picture: what head office gets today by stacking the stores' files and
-- summing the amount column. GST-inclusive and GST-exclusive figures are mixed, refunds
-- are added instead of subtracted where the sign is not in the amount, and double
-- exports are counted twice. Kept only to measure how wrong that picture is.
select store_code, source_system, count(*) as rows_received, sum(amount_as_reported) as amount_as_reported
from {{ ref('stg_pos_a__sales') }}
group by all

union all

select store_code, source_system, count(*), sum(amount_as_reported)
from {{ ref('stg_pos_b__sales') }}
group by all

union all

select
    {{ store_from_filename() }}, 'pos_c', count(*), sum(cast(line_total_incl_gst as decimal(12, 2)))
from {{ source('pos_c', 'sales') }}
group by all
