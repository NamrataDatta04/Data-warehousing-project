-- One row per calendar day, with the attributes New Zealand reporting needs:
-- 1 April - 31 March financial year, southern-hemisphere seasons, national public holidays.
with days as (
    {{ date_spine('2024-07-01', '2026-06-30') }}
)

select
    {{ date_key('d.calendar_date') }}                              as date_key,
    d.calendar_date,
    case {{ iso_day_of_week('d.calendar_date') }}
        when 1 then 'Monday' when 2 then 'Tuesday' when 3 then 'Wednesday' when 4 then 'Thursday'
        when 5 then 'Friday' when 6 then 'Saturday' else 'Sunday' end as day_name,
    {{ iso_day_of_week('d.calendar_date') }}                      as day_of_week,
    {{ iso_day_of_week('d.calendar_date') }} >= 6                 as is_weekend,
    month(d.calendar_date)                                        as month_number,
    case month(d.calendar_date)
        when 1 then 'January' when 2 then 'February' when 3 then 'March' when 4 then 'April'
        when 5 then 'May' when 6 then 'June' when 7 then 'July' when 8 then 'August'
        when 9 then 'September' when 10 then 'October' when 11 then 'November' else 'December' end
                                                                  as month_name,
    cast(date_trunc('month', d.calendar_date) as date)            as month_start,
    quarter(d.calendar_date)                                      as quarter_number,
    year(d.calendar_date) || 'Q' || quarter(d.calendar_date)      as quarter_label,
    cast(date_trunc('quarter', d.calendar_date) as date)          as quarter_start,
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
