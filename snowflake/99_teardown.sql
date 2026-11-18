/* =============================================================================
   99_teardown.sql - remove everything 01 and 02 created

   Run when the project is finished, so nothing keeps using trial credits.
   This deletes the warehouse data permanently.
   ============================================================================= */

use role accountadmin;
drop database if exists kereru_dw;
drop warehouse if exists transforming_wh;
drop resource monitor if exists kereru_monitor;
drop user if exists dbt_svc;
drop role if exists transformer;
