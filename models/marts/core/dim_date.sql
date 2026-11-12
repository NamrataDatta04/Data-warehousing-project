-- One row per calendar day, with the attributes New Zealand reporting needs:
-- 1 April - 31 March financial year, southern-hemisphere seasons, national public holidays.
with days as (
    select cast(unnest(generate_series(date '2024-07-01', date '2026-06-30', interval 1 day)) as date) as calendar_date
)

select
    cast(strftime(d.calendar_date, '%Y%m%d') as integer)          as date_key,
    d.calendar_date,
    dayname(d.calendar_date)                                      as day_name,
    isodow(d.calendar_date)                                       as day_of_week,
    isodow(d.calendar_date) >= 6                                  as is_weekend,
    month(d.calendar_date)                                        as month_number,
    monthname(d.calendar_date)                                    as month_name,
    date_trunc('month', d.calendar_date)::date                    as month_start,
    quarter(d.calendar_date)                                      as quarter_number,
    year(d.calendar_date) || 'Q' || quarter(d.calendar_date)      as quarter_label,
    date_trunc('quarter', d.calendar_date)::date                  as quarter_start,
    year(d.calendar_date)                                         as calendar_year,
    'FY' || (year(d.calendar_date) + case when month(d.calendar_date) >= 4 then 1 else 0 end)
                                                                  as nz_financial_year,
    case when month(d.calendar_date) in (12, 1, 2) then 'Summer'
         when month(d.calendar_date) in (3, 4, 5)  then 'Autumn'
         when month(d.calendar_date) in (6, 7, 8)  then 'Winter'
         else 'Spring' end                                        as season,
    h.holiday_date is not null                                    as is_public_holiday,
    h.holiday_name
from days as d
left join {{ ref('nz_public_holidays') }} as h
    on d.calendar_date = h.holiday_date
