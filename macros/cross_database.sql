{#
  The few SQL functions that differ between DuckDB (local runs and CI) and Snowflake.
  Each macro has a default__ version (DuckDB) and a snowflake__ version; dbt picks the
  right one for the active target, so every model stays a single file.
#}

{# Store code from the path of a source file, e.g. pos_a/AKL01/sales_2025Q1.csv -> AKL01 #}
{% macro store_from_filename() -%}
    {{ return(adapter.dispatch('store_from_filename')()) }}
{%- endmacro %}
{% macro default__store_from_filename() -%}
    regexp_extract(filename, '([A-Z]{3}[0-9]{2})[/\\][^/\\]+$', 1)
{%- endmacro %}
{% macro snowflake__store_from_filename() -%}
    regexp_substr(filename, '([A-Z]{3}[0-9]{2})/[^/]+$', 1, 1, 'e', 1)
{%- endmacro %}

{# First capture group of a regular expression. Keep patterns free of backslashes. #}
{% macro regex_group(column, pattern) -%}
    {{ return(adapter.dispatch('regex_group')(column, pattern)) }}
{%- endmacro %}
{% macro default__regex_group(column, pattern) -%}
    regexp_extract({{ column }}, '{{ pattern }}', 1)
{%- endmacro %}
{% macro snowflake__regex_group(column, pattern) -%}
    regexp_substr({{ column }}, '{{ pattern }}', 1, 1, 'e', 1)
{%- endmacro %}

{# Replace every run of whitespace with a single space #}
{% macro collapse_spaces(column) -%}
    {{ return(adapter.dispatch('collapse_spaces')(column)) }}
{%- endmacro %}
{% macro default__collapse_spaces(column) -%}
    regexp_replace({{ column }}, '[[:space:]]+', ' ', 'g')
{%- endmacro %}
{% macro snowflake__collapse_spaces(column) -%}
    regexp_replace({{ column }}, '[[:space:]]+', ' ')
{%- endmacro %}

{# Text to date. Formats are written the Snowflake way and translated for DuckDB. #}
{% macro parse_date(column, format) -%}
    {{ return(adapter.dispatch('parse_date')(column, format)) }}
{%- endmacro %}
{% macro default__parse_date(column, format) -%}
    {%- set duckdb_formats = {'DD/MM/YYYY': '%d/%m/%Y', 'DD-MON-YY': '%d-%b-%y', 'YYYY-MM-DD': '%Y-%m-%d'} -%}
    cast(strptime({{ column }}, '{{ duckdb_formats[format] }}') as date)
{%- endmacro %}
{% macro snowflake__parse_date(column, format) -%}
    to_date({{ column }}, '{{ format }}')
{%- endmacro %}

{% macro sha256_hex(column) -%}
    {{ return(adapter.dispatch('sha256_hex')(column)) }}
{%- endmacro %}
{% macro default__sha256_hex(column) -%}
    sha256({{ column }})
{%- endmacro %}
{% macro snowflake__sha256_hex(column) -%}
    sha2({{ column }}, 256)
{%- endmacro %}

{# True if any row in the group is true #}
{% macro bool_or(column) -%}
    {{ return(adapter.dispatch('bool_or')(column)) }}
{%- endmacro %}
{% macro default__bool_or(column) -%}
    bool_or({{ column }})
{%- endmacro %}
{% macro snowflake__bool_or(column) -%}
    boolor_agg({{ column }})
{%- endmacro %}

{# Integer date key, e.g. 2025-03-31 -> 20250331 #}
{% macro date_key(column) -%}
    {{ return(adapter.dispatch('date_key')(column)) }}
{%- endmacro %}
{% macro default__date_key(column) -%}
    cast(strftime({{ column }}, '%Y%m%d') as integer)
{%- endmacro %}
{% macro snowflake__date_key(column) -%}
    cast(to_char({{ column }}, 'YYYYMMDD') as integer)
{%- endmacro %}

{% macro date_from_parts(year, month, day) -%}
    {{ return(adapter.dispatch('date_from_parts')(year, month, day)) }}
{%- endmacro %}
{% macro default__date_from_parts(year, month, day) -%}
    make_date({{ year }}, {{ month }}, {{ day }})
{%- endmacro %}
{% macro snowflake__date_from_parts(year, month, day) -%}
    date_from_parts({{ year }}, {{ month }}, {{ day }})
{%- endmacro %}

{# ISO day of week: Monday = 1 ... Sunday = 7 #}
{% macro iso_day_of_week(column) -%}
    {{ return(adapter.dispatch('iso_day_of_week')(column)) }}
{%- endmacro %}
{% macro default__iso_day_of_week(column) -%}
    isodow({{ column }})
{%- endmacro %}
{% macro snowflake__iso_day_of_week(column) -%}
    dayofweekiso({{ column }})
{%- endmacro %}

{# One row per day from start_date to end_date inclusive, in a column called calendar_date #}
{% macro date_spine(start_date, end_date) -%}
    {{ return(adapter.dispatch('date_spine')(start_date, end_date)) }}
{%- endmacro %}
{% macro default__date_spine(start_date, end_date) -%}
    select cast(unnest(generate_series(date '{{ start_date }}', date '{{ end_date }}', interval 1 day)) as date) as calendar_date
{%- endmacro %}
{% macro snowflake__date_spine(start_date, end_date) -%}
    {%- set days = (modules.datetime.date.fromisoformat(end_date) - modules.datetime.date.fromisoformat(start_date)).days + 1 -%}
    select dateadd(day, row_number() over (order by seq4()) - 1, date '{{ start_date }}') as calendar_date
    from table(generator(rowcount => {{ days }}))
{%- endmacro %}
