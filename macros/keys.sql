{# Deterministic surrogate key: md5 of the business-key columns. #}
{% macro surrogate_key(columns) -%}
    md5(concat_ws('|', {% for c in columns %}coalesce(cast({{ c }} as varchar), '~'){% if not loop.last %}, {% endif %}{% endfor %}))
{%- endmacro %}

{# Customers are matched across stores on a cleaned email address. Only its SHA-256
   hash is kept, so no direct identifier travels past the staging layer. #}
{% macro customer_id(email_column) -%}
    case when nullif(trim({{ email_column }}), '') is null then null
         else sha256(lower(trim({{ email_column }}))) end
{%- endmacro %}

{# Store code from the folder a file was read from, e.g. data/raw/pos_a/AKL01/sales_2025Q1.csv #}
{% macro store_from_filename() -%}
    regexp_extract(filename, '([A-Z]{3}[0-9]{2})[/\\][^/\\]+$', 1)
{%- endmacro %}
