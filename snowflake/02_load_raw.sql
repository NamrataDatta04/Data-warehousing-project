/* =============================================================================
   02_load_raw.sql - load the source files from Azure Blob Storage into RAW

   Run in a Snowsight SQL worksheet after 01_setup.sql, from top to bottom.
   Before running, replace in the CREATE STAGE statement:
     <storage-account>  your Azure storage account name, e.g. kereruhardware2026
     <sas-token>        a read-and-list SAS token for the 'raw' container
                        (it starts with sp= or sv=; leave out any leading '?')

   Every column is loaded as text, exactly as the stores sent it. Typing, cleaning
   and GST conversion happen in dbt, so a bad value fails a test instead of a load.
   Safe to re-run: each table is recreated, so files are never loaded twice.

   Production note: a STORAGE INTEGRATION (Azure service principal) is the better
   choice for a long-lived pipeline, as no token is kept in the stage. A short-lived
   SAS token keeps this demo to a single script.
   ============================================================================= */

use role sysadmin;
use warehouse transforming_wh;
use schema kereru_dw.raw;

create or replace file format csv_with_header
    type = csv
    skip_header = 1
    field_optionally_enclosed_by = '"'
    empty_field_as_null = true
    encoding = 'UTF8';

create or replace stage raw_stage
    url = 'azure://<storage-account>.blob.core.windows.net/raw/'
    credentials = (azure_sas_token = '<sas-token>')
    file_format = csv_with_header
    comment = 'The raw container in Azure Blob Storage';

-- Should list 136 files. If this fails, the account name or SAS token is wrong.
list @raw_stage;

-- POS A (5 stores) -------------------------------------------------------------
create or replace table pos_a_sales (
    txn_id varchar, line_no varchar, sold_at varchar, sku varchar, qty varchar,
    unit_price_excl_gst varchar, discount_pct varchar, cust_id varchar, is_return varchar,
    filename varchar
);
copy into pos_a_sales
from (select $1, $2, $3, $4, $5, $6, $7, $8, $9, metadata$filename from @raw_stage/pos_a/)
pattern = '.*sales_.*[.]csv';

create or replace table pos_a_customers (
    cust_id varchar, first_name varchar, last_name varchar, email varchar, customer_type varchar,
    filename varchar
);
copy into pos_a_customers
from (select $1, $2, $3, $4, $5, metadata$filename from @raw_stage/pos_a/)
pattern = '.*customers[.]csv';

-- POS B (4 stores): column names keep the till's own spelling ----------------
create or replace table pos_b_sales (
    "Receipt No" varchar, "Date" varchar, "Time" varchar, "Item Code" varchar, "Qty" varchar,
    "Price Inc GST" varchar, "Disc $" varchar, "Cust Ref" varchar, "Type" varchar,
    filename varchar
);
copy into pos_b_sales
from (select $1, $2, $3, $4, $5, $6, $7, $8, $9, metadata$filename from @raw_stage/pos_b/)
pattern = '.*sales_.*[.]csv';

create or replace table pos_b_customers (
    "Cust Ref" varchar, "Full Name" varchar, "Email" varchar, "Account Type" varchar,
    filename varchar
);
copy into pos_b_customers
from (select $1, $2, $3, $4, metadata$filename from @raw_stage/pos_b/)
pattern = '.*customers[.]csv';

-- POS C (3 stores, spreadsheet exports) --------------------------------------
create or replace table pos_c_sales (
    invoice_ref varchar, sale_date varchar, product varchar, quantity varchar,
    line_total_incl_gst varchar, customer_email varchar, account_type varchar,
    filename varchar
);
copy into pos_c_sales
from (select $1, $2, $3, $4, $5, $6, $7, metadata$filename from @raw_stage/pos_c/)
pattern = '.*sales_.*[.]csv';

-- Head-office reference data --------------------------------------------------
create or replace table stores (
    store_code varchar, store_name varchar, suburb varchar, city varchar, region varchar,
    island varchar, pos_system varchar, opened_on varchar, floor_area_m2 varchar
);
copy into stores from @raw_stage/reference/ files = ('stores.csv');

create or replace table product_catalogue (
    sku varchar, product_name varchar, category varchar, brand varchar,
    unit_of_measure varchar, supplier_code varchar
);
copy into product_catalogue from @raw_stage/reference/ files = ('product_catalogue.csv');

create or replace table price_list (
    sku varchar, effective_from varchar, list_price_excl_gst varchar, standard_cost varchar
);
copy into price_list from @raw_stage/reference/ files = ('price_list.csv');

create or replace table suppliers (
    supplier_code varchar, supplier_name varchar, country varchar, lead_time_days varchar
);
copy into suppliers from @raw_stage/reference/ files = ('suppliers.csv');

create or replace table pos_b_item_map (
    store_code varchar, item_code varchar, sku varchar
);
copy into pos_b_item_map from @raw_stage/reference/ files = ('pos_b_item_map.csv');

-- Monthly stock counts ----------------------------------------------------------
create or replace table inventory_stock (
    store_code varchar, sku varchar, on_hand_qty varchar, received_qty varchar,
    stockout_days varchar, filename varchar
);
copy into inventory_stock
from (select $1, $2, $3, $4, $5, metadata$filename from @raw_stage/inventory/)
pattern = '.*stock_.*[.]csv';

-- Finance -------------------------------------------------------------------------
create or replace table opex_quarterly (
    store_code varchar, quarter varchar, rent varchar, wages varchar,
    utilities varchar, marketing varchar, other varchar
);
copy into opex_quarterly from @raw_stage/finance/ files = ('opex_quarterly.csv');

create or replace table control_totals (
    store_code varchar, quarter varchar, net_sales_excl_gst varchar
);
copy into control_totals from @raw_stage/finance/ files = ('control_totals.csv');

-- Check: every row should say OK -------------------------------------------------
select table_name, loaded_rows, expected_rows,
       iff(loaded_rows = expected_rows, 'OK', 'CHECK') as status
from (
              select 'pos_a_sales'       as table_name, (select count(*) from pos_a_sales)       as loaded_rows, 152418 as expected_rows
    union all select 'pos_a_customers',   (select count(*) from pos_a_customers),   5495
    union all select 'pos_b_sales',       (select count(*) from pos_b_sales),       86239
    union all select 'pos_b_customers',   (select count(*) from pos_b_customers),   3233
    union all select 'pos_c_sales',       (select count(*) from pos_c_sales),       60936
    union all select 'stores',            (select count(*) from stores),            12
    union all select 'product_catalogue', (select count(*) from product_catalogue), 67
    union all select 'price_list',        (select count(*) from price_list),        134
    union all select 'suppliers',         (select count(*) from suppliers),         9
    union all select 'pos_b_item_map',    (select count(*) from pos_b_item_map),    268
    union all select 'inventory_stock',   (select count(*) from inventory_stock),   19296
    union all select 'opex_quarterly',    (select count(*) from opex_quarterly),    96
    union all select 'control_totals',    (select count(*) from control_totals),    96
)
order by table_name;
