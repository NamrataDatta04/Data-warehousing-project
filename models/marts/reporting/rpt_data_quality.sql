-- What the pipeline had to fix on the way in, per source system.
with received as (
    select source_system, sum(rows_received) as rows_received, sum(amount_as_reported) as amount_as_reported
    from {{ ref('int_sales_as_reported') }}
    group by source_system
),

loaded as (
    select
        source_system,
        count(*)                                               as rows_loaded,
        sum(net_amount_excl_gst)                               as net_sales_excl_gst,
        sum(case when is_return then 1 else 0 end)             as refund_lines,
        sum(case when is_return then -net_amount_excl_gst else 0 end) as refund_value
    from {{ ref('fct_sales') }}
    group by source_system
)

select
    r.source_system,
    case r.source_system
        when 'pos_a' then 'ISO dates, GST-exclusive, refund flag'
        when 'pos_b' then 'dd/mm/yyyy, GST-inclusive, local item codes, refund row type'
        else 'd-Mon-yy, free-text products, GST-inclusive totals, negative refunds'
    end                                                        as source_format,
    (select count(*) from {{ ref('dim_store') }} as s where s.pos_system = r.source_system) as stores,
    r.rows_received,
    r.rows_received - l.rows_loaded                            as duplicate_rows_removed,
    l.rows_loaded,
    l.refund_lines,
    round(l.refund_value)                                      as refund_value,
    round(r.amount_as_reported)                                as amount_as_reported,
    round(l.net_sales_excl_gst)                                as net_sales_excl_gst,
    round(100.0 * (r.amount_as_reported / l.net_sales_excl_gst - 1), 1) as overstated_pct
from received as r
join loaded   as l on r.source_system = l.source_system
order by r.source_system
