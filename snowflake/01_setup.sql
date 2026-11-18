/* =============================================================================
   01_setup.sql - one-time Snowflake setup for the Kereru warehouse

   Run in a Snowsight SQL worksheet, signed in as the account owner (a user with
   the ACCOUNTADMIN role, which every trial owner has). Run it from top to bottom.

   Before running, replace <public-key> near the end with the text printed by
   scripts/make_snowflake_key.py. Never paste the PRIVATE key here.

   Creates:
     - a monthly credit limit (resource monitor) so the trial cannot run away
     - an extra-small warehouse that suspends itself after 60 seconds idle
     - the KERERU_DW database with a RAW schema for the loaded files
     - a TRANSFORMER role that dbt uses: it can read RAW and build its own schemas
     - a DBT_SVC service user that signs in with a key pair, never a password
   ============================================================================= */

-- 1. Cost guard ---------------------------------------------------------------
use role accountadmin;

create resource monitor if not exists kereru_monitor
    with credit_quota = 10
         frequency = monthly
         start_timestamp = immediately
    triggers on 80 percent do notify
             on 100 percent do suspend;

-- 2. Compute and storage (created by SYSADMIN, as Snowflake recommends) -------
use role sysadmin;

create warehouse if not exists transforming_wh
    warehouse_size = xsmall
    auto_suspend = 60
    auto_resume = true
    initially_suspended = true
    comment = 'dbt builds and loading for the Kereru warehouse';

create database if not exists kereru_dw comment = 'Kererū Hardware Co-operative data warehouse';
create schema if not exists kereru_dw.raw comment = 'Source files loaded as text from Azure Blob Storage';

use role accountadmin;
alter warehouse transforming_wh set resource_monitor = kereru_monitor;

-- 3. Role for dbt (roles and users are managed by SECURITYADMIN) --------------
use role securityadmin;

create role if not exists transformer comment = 'Reads RAW and builds the dbt schemas';
grant role transformer to role sysadmin;          -- so your own login can see what dbt builds

grant usage on warehouse transforming_wh to role transformer;
grant usage, create schema on database kereru_dw to role transformer;
grant usage on schema kereru_dw.raw to role transformer;
grant select on all tables in schema kereru_dw.raw to role transformer;
grant select on future tables in schema kereru_dw.raw to role transformer;

-- 4. Service user for dbt -----------------------------------------------------
create user if not exists dbt_svc
    type = service
    default_role = transformer
    default_warehouse = transforming_wh
    comment = 'dbt runs for the Kereru warehouse (key-pair sign-in only)';

alter user dbt_svc set rsa_public_key = '<public-key>';

grant role transformer to user dbt_svc;

-- 5. Check: the key fingerprint should start with SHA256:
desc user dbt_svc;
