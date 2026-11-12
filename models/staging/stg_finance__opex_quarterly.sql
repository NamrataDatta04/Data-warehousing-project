select
    store_code,
    quarter                                                        as quarter_label,
    make_date(cast(left(quarter, 4) as integer), cast(right(quarter, 1) as integer) * 3 - 2, 1) as quarter_start,
    cast(rent as decimal(14, 2))           as rent_expense,
    cast(wages as decimal(14, 2))          as wages_expense,
    cast(utilities as decimal(14, 2))      as utilities_expense,
    cast(marketing as decimal(14, 2))      as marketing_expense,
    cast(other as decimal(14, 2))          as other_expense
from {{ source('finance', 'opex_quarterly') }}
