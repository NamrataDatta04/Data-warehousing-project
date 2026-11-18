# Running the warehouse on Snowflake with Azure

The same dbt project builds in two places:

| Target | Where the data comes from | Command |
|---|---|---|
| `dev` (default) | CSV files in `data/raw`, read by DuckDB | `dbt build --profiles-dir .` |
| `snowflake` | Tables in `KERERU_DW.RAW`, loaded from Azure Blob Storage | `dbt build --profiles-dir . --target snowflake` |

The handful of SQL functions that differ between the two (dates, regular expressions,
hashing, the date spine) live in [`macros/cross_database.sql`](../macros/cross_database.sql),
so every model is written once.

```
generate_source_data.py ─► Azure Blob Storage ─► Snowflake RAW ─► dbt (staging ─► core ─► reporting)
                           container "raw"        COPY INTO          role TRANSFORMER, user DBT_SVC
```

## Steps

1. Generate the source files and upload them to a container called `raw`:
   `python scripts/generate_source_data.py`, then `python scripts/upload_to_azure.py`
   with `AZURE_STORAGE_CONNECTION_STRING` set (`pip install -r requirements-azure.txt`).
2. Install the Snowflake adapter: `pip install -r requirements-snowflake.txt`.
3. Create the key pair dbt signs in with: `python scripts/make_snowflake_key.py`.
4. In a Snowsight worksheet, run [`01_setup.sql`](01_setup.sql) with the public key pasted in.
5. In a Snowsight worksheet, run [`02_load_raw.sql`](02_load_raw.sql) with your storage account
   name and a read-and-list SAS token for the container pasted in. The last query should say OK for every table.
6. Set `SNOWFLAKE_ACCOUNT` (your account identifier, `ORGNAME-ACCOUNTNAME`) and
   `SNOWFLAKE_PRIVATE_KEY_PATH`, then run `dbt build --profiles-dir . --target snowflake`.
7. When finished, run [`99_teardown.sql`](99_teardown.sql) so nothing keeps using credits.

## Security choices

- dbt connects as `DBT_SVC`, a Snowflake service user that can only sign in with a key pair.
  The private key stays in your home folder and is ignored by Git.
- `TRANSFORMER` can read `RAW` and create its own schemas, nothing else.
- Objects are created by `SYSADMIN` and roles and users by `SECURITYADMIN`, as Snowflake recommends;
  `ACCOUNTADMIN` is used only for the credit limit.
- A resource monitor suspends the warehouse at 10 credits a month; the warehouse suspends after 60 seconds idle.
- The stage uses a short-lived SAS token. For a long-lived pipeline, a storage integration is the better choice,
  as no token is kept in Snowflake.
