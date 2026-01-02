# Query Snowflake Iceberg Tables with DuckDB

A quick demo showing how to query Snowflake-managed Iceberg tables using DuckDB through the [Horizon Iceberg REST Catalog](https://docs.snowflake.com/en/user-guide/tables-iceberg-query-using-external-query-engine-snowflake-horizon).

## What's This About?

Snowflake's Horizon Catalog now exposes Iceberg REST APIs, which means you can use external query engines like DuckDB, Spark, or Trino to read your Snowflake-managed Iceberg tables directly. No data copying, no ETL—just point your engine at Horizon and query away.

This demo walks through setting it up with DuckDB.

> [!NOTE]
> This feature is in [Preview](https://docs.snowflake.com/en/user-guide/tables-iceberg-query-using-external-query-engine-snowflake-horizon) and works in all public regions except government ones. No charges during preview.

## What You'll Need

### Tools

- [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index) (`snow`)
- [snow-bin-utils](https://github.com/kameshsampath/snow-bin-utils) for automating Snowflake object setup
- [Task](https://taskfile.dev/) for running the automation scripts
- [gettext](https://www.gnu.org/software/gettext/) for `envsubst` (used by the DuckDB CLI demo)
- Python 3.12+ with [uv](https://docs.astral.sh/uv/)
- [direnv](https://direnv.net/) (optional but recommended)

### Installing Task & gettext

```bash
# macOS
brew install go-task gettext

# Linux - Task
sudo snap install task --classic
# or
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin
# gettext is usually pre-installed on Linux

# Windows (scoop)
scoop install task gettext

# Windows (choco)
choco install go-task gettext
```

### Snowflake Requirements

- A [Snowflake account](https://bit.ly/snow-india-meetups) (free trial works!)
- An [External Volume](https://docs.snowflake.com/en/sql-reference/sql/create-external-volume) pointing to S3, Azure, or GCS
- Some [Snowflake-managed Iceberg tables](https://docs.snowflake.com/en/user-guide/tables-iceberg-create) to query (or use the sample data task below)

## Getting Started

### 1. Set Up Your Environment

```bash
cp env.example .env
```

Fill in your details:

```bash
SNOWFLAKE_ACCOUNT=myorg-myaccount
SNOWFLAKE_ACCOUNT_URL=https://myorg-myaccount.snowflakecomputing.com
SNOWFLAKE_USER=kamesh

# This will hold your PAT token after step 2
SNOWFLAKE_PASSWORD=

DEMO_DATABASE=MY_ICEBERG_DB
EXTERNAL_VOLUME_NAME=my_external_volume

# Service account for Horizon access
SA_USER=iceberg_reader
SA_ROLE=iceberg_reader_role    # NO hyphens allowed!
SA_ADMIN_ROLE=accountadmin

PAT_OBJECTS_DB=pat_admin
```

> [!IMPORTANT]
> Roles with hyphens (`-`) in the name [won't work](https://docs.snowflake.com/en/user-guide/tables-iceberg-query-using-external-query-engine-snowflake-horizon#considerations-for-querying-iceberg-tables-with-an-external-query-engine) with Horizon Catalog. Use underscores instead.

### 2. Set Up Snowflake Objects

If you have `snow-bin-utils` installed, this is straightforward:

```bash
# Create external volume (if you don't have one)
task create-external-volume

# Set up database and roles
task setup-snowflake

# Generate a PAT token for authentication
task create-or-rotate-pat
```

> [!TIP]
> The PAT task will update your `.env` file with the token automatically.

If you prefer doing it manually, check the SQL files in this repo and run them with `snow sql`.

### 3. Create Sample Data (Optional)

If you don't have existing Iceberg tables, create a sample one:

```bash
task create-sample-data
```

This creates a `fruits` table with some test data. Since DuckDB can't write to Iceberg tables through Horizon Catalog, we create data via Snowflake first.

### 4. Grant Access to Your Tables

```bash
task setup-rbac
```

Or manually grant SELECT on any tables you want to query:

```sql
GRANT SELECT ON TABLE my_db.my_schema.my_table TO ROLE iceberg_reader_role;
```

### 5. Fire Up Python

With direnv:

```bash
direnv allow
```

Or manually:

```bash
uv venv && source .venv/bin/activate && uv sync
```

### 6. Run the Demo

Open `workbook.ipynb` in Jupyter, or run the CLI version:

```bash
source .env && envsubst < demo.sql | duckdb
```

## How It Works

The magic happens through a PAT (Programmatic Access Token) that DuckDB exchanges for temporary credentials:

```sql
-- DuckDB creates a secret with your PAT
CREATE SECRET iceberg_secret (
    TYPE iceberg,
    CLIENT_ID '',
    CLIENT_SECRET '<your_pat>',
    OAUTH2_SERVER_URI 'https://<account>.snowflakecomputing.com/polaris/api/catalog/v1/oauth/tokens',
    OAUTH2_GRANT_TYPE 'client_credentials',
    OAUTH2_SCOPE 'session:role:iceberg_reader_role'
);

-- Then attaches to your Snowflake database
ATTACH 'MY_ICEBERG_DB' AS sf (
    TYPE iceberg,
    SECRET iceberg_secret,
    ENDPOINT 'https://<account>.snowflakecomputing.com/polaris/api/catalog'
);

-- And you're off to the races
SELECT * FROM sf.my_schema.my_table LIMIT 10;
```

Horizon handles vending temporary cloud credentials so DuckDB can read directly from your object storage.

## Things to Keep in Mind

> [!WARNING]
>
> - External engines can query but **can't write** to Iceberg tables
> - External reads work on **Iceberg v2 or earlier** only
> - Tables with [row access policies](https://docs.snowflake.com/en/user-guide/security-row-intro) or [masking policies](https://docs.snowflake.com/en/user-guide/security-column-intro) aren't accessible via Horizon
> - Only **Snowflake-managed** Iceberg tables are supported (not externally managed or Delta/Parquet Direct)

## Troubleshooting

### Debugging HTTP requests

If you need to inspect the HTTP traffic between DuckDB and Horizon Catalog, you can use [mitmproxy](https://mitmproxy.org/):

```bash
# Start mitmproxy
mitmproxy --listen-port 8080
```

Then in DuckDB (or the notebook), configure the proxy and certificate:

```sql
-- Load the mitmproxy CA certificate
LOAD httpfs;
SET ca_cert_file = '~/.mitmproxy/mitmproxy-ca.pem';
SET enable_server_cert_verification = true;

-- Configure HTTP proxy
CREATE OR REPLACE SECRET http_proxy (
    TYPE http,
    HTTP_PROXY 'http://localhost:8080'
);
```

### PAT authentication fails

- Check your PAT hasn't expired: `snow-utils snow:pats`
- Verify the role is granted to the user
- Ensure network policies allow your IP

### "Role not found" errors

Role names with hyphens (`-`) aren't supported. Use underscores instead.

### Can't see tables

Make sure `GRANT SELECT` was run for each table you want to query. The service account role needs explicit access.

## Links

- [Unlock Open Interoperability with Horizon Catalog](https://medium.com/snowflake/unlock-open-interoperability-with-horizon-catalog-89ae67b7ee66) — great intro blog post
- [Horizon Catalog docs](https://docs.snowflake.com/en/user-guide/tables-iceberg-query-using-external-query-engine-snowflake-horizon)
- [Iceberg tables in Snowflake](https://docs.snowflake.com/en/user-guide/tables-iceberg)
- [PAT documentation](https://docs.snowflake.com/en/user-guide/programmatic-access-tokens)
- [snow-bin-utils](https://github.com/kameshsampath/snow-bin-utils)
- [DuckDB Iceberg extension](https://duckdb.org/docs/extensions/iceberg.html)
- [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index)
