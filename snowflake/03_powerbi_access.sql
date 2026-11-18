/* =============================================================================
   03_powerbi_access.sql - a read-only login for Power BI

   Run in a Snowsight SQL worksheet with Run All, after dbt has built the warehouse
   at least once (the CORE and REPORTING schemas must exist).

   Before running, replace <public-key> with the public key printed by:
       python scripts/make_snowflake_key.py --user powerbi_svc --encrypt

   Creates:
     - a REPORTER role that can only read the CORE and REPORTING schemas
       (not RAW, which holds the stores' customer names and emails)
     - a POWERBI_SVC service user that signs in with an encrypted key pair
   ============================================================================= */

use role securityadmin;

create role if not exists reporter comment = 'Read-only access to CORE and REPORTING for Power BI';
grant role reporter to role sysadmin;

grant usage on warehouse transforming_wh to role reporter;
grant usage on database kereru_dw to role reporter;

grant usage on schema kereru_dw.core to role reporter;
grant usage on schema kereru_dw.reporting to role reporter;

-- dbt recreates its tables on every build, so future grants keep access in place
grant select on all tables in schema kereru_dw.core to role reporter;
grant select on future tables in schema kereru_dw.core to role reporter;
grant select on all tables in schema kereru_dw.reporting to role reporter;
grant select on future tables in schema kereru_dw.reporting to role reporter;

create user if not exists powerbi_svc
    type = service
    default_role = reporter
    default_warehouse = transforming_wh
    comment = 'Power BI reports for the Kereru warehouse (key-pair sign-in only)';

alter user powerbi_svc set rsa_public_key = '<public-key>';

grant role reporter to user powerbi_svc;

-- Check: RSA_PUBLIC_KEY_FP should start with SHA256:
desc user powerbi_svc;
