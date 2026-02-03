# Query Snowflake Iceberg Tables with DuckDB

A quick demo showing how to query Snowflake-managed Iceberg tables using DuckDB through the [Horizon Iceberg REST Catalog](https://docs.snowflake.com/en/user-guide/tables-iceberg-query-using-external-query-engine-snowflake-horizon).


---

## 🎬 Demo Video

[![Watch the Demo](https://img.shields.io/badge/YouTube-Watch%20Demo-red?style=for-the-badge&logo=youtube)]([https://youtu.be/fbCA06cdUTU](https://youtu.be/vpbUbh4KRwo))

---

## What's This About?

Snowflake's Horizon Catalog now exposes Iceberg REST APIs, which means you can use external query engines like DuckDB, Spark, or Trino to read your Snowflake-managed Iceberg tables directly. No data copying, no ETL—just point your engine at Horizon and query away.

This demo walks through setting it up with DuckDB.

> [!NOTE]
> This feature is in [Preview](https://docs.snowflake.com/en/user-guide/tables-iceberg-query-using-external-query-engine-snowflake-horizon) and works in all public regions except government ones. No charges during preview.

## What You'll Need

### Tools

- [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index) (`snow`)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) with credentials configured
- [snow-bin-utils](https://github.com/kameshsampath/snow-bin-utils) for automating Snowflake object setup, check [Install `snow-bin-utils` (Snow Utils)](https://youtu.be/zEzf-Rpv8Dc)
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

### Installing snow-bin-utils

[snow-bin-utils](https://github.com/kameshsampath/snow-bin-utils) automates Snowflake infrastructure setup (external volumes, PATs, policies).

```bash
# Clone the repo
git clone https://github.com/kameshsampath/snow-bin-utils.git
cd snow-bin-utils

# Add to your PATH (add this to your ~/.bashrc or ~/.zshrc)
export PATH="$PATH:$(pwd)"

# Verify installation
snow-utils --help
```

See the [full installation guide](https://github.com/kameshsampath/snow-bin-utils?tab=readme-ov-file#installation) for more details.

### AWS Requirements

You need an AWS account with permissions to:

- Create and manage S3 buckets
- Create IAM policies and roles (for Snowflake external volume trust relationship)

Verify your AWS credentials are configured:

```bash
aws sts get-caller-identity
```

> [!IMPORTANT]
> This command must succeed before proceeding to step 2.

### Snowflake Requirements

- A [Snowflake account](https://bit.ly/snow-india-meetups) with `ACCOUNTADMIN` role (or equivalent privileges to create roles, databases, external volumes, network policies, authentication policies, and network rules)

> [!TIP]
> For simplicity, we recommend using a [Snowflake Free Trial](https://bit.ly/snow-india-meetups) with `ACCOUNTADMIN` for this demo.

## Getting Started

### 1. Set Up Your Environment

```bash
cp env.example .env
```

Fill in your details:

```bash
# AWS credentials
AWS_PROFILE=default

# Snowflake settings
SNOWFLAKE_ACCOUNT=myorg-myaccount
SNOWFLAKE_ACCOUNT_URL=https://myorg-myaccount.snowflakecomputing.com
SNOWFLAKE_USER=your snowflake username

# Leave empty - will be auto-populated
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

```bash
# Create external volume (creates S3 bucket and IAM roles)
task create-external-volume

# Set up database and roles
task setup-snowflake

# Generate PAT token for authentication
task create-or-rotate-pat
```

> [!NOTE]
> The `create-or-rotate-pat` task creates:
>
> - A [Programmatic Access Token (PAT)](https://docs.snowflake.com/en/user-guide/programmatic-access-tokens)
> - A [Network Policy](https://docs.snowflake.com/en/user-guide/network-policies) allowing only your current public IP
> - An [Authentication Policy](https://docs.snowflake.com/en/user-guide/authentication-policies) for the service account
>
> The PAT is automatically saved to your `.env` file.

### 3. Create Sample Data (Optional)

If you don't have existing Iceberg tables, create a sample one:

```bash
task create-sample-data
```

> [!IMPORTANT]
> This creates a `FRUITS` table with test data. Since DuckDB can't write to Iceberg tables through Horizon Catalog, we create data via Snowflake first.

### 4. Fire Up Python

With direnv:

```bash
direnv allow
```

Or manually:

```bash
uv venv && source .venv/bin/activate && uv sync
```

### 5. Run the Demo (Expect it to fail!)

Open `workbook.ipynb` in Jupyter, or run the CLI version:

```bash
source .env && envsubst < demo.sql | duckdb -bail 
```

> [!WARNING]
> This will fail with a permissions error! The service account role doesn't have access to the tables yet. This is intentional—proceed to step 6.

### 6. Grant Access to Your Tables

Now grant the service account role access to your tables:

```bash
task setup-rbac
```

Or manually:

```sql
GRANT SELECT ON TABLE $DEMO_DATABASE.PUBLIC.FRUITS TO ROLE $SA_ROLE;
```

### 7. Run the Demo Again (Success!)

```bash
source .env && envsubst < demo.sql | duckdb -bail
```

This time it should work! 🎉

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
SELECT * FROM sf.PUBLIC.FRUITS LIMIT 10;
```

Horizon handles vending temporary cloud credentials so DuckDB can read directly from your object storage.

## Things to Keep in Mind

> [!WARNING]
>
> - External engines can query but **can't write** to Iceberg tables
> - External reads work on **Iceberg v2 or earlier** only
> - Tables with [row access policies](https://docs.snowflake.com/en/user-guide/security-row-intro) or [masking policies](https://docs.snowflake.com/en/user-guide/security-column-intro) aren't accessible via Horizon
> - Only **Snowflake-managed** Iceberg tables are supported (not externally managed or Delta/Parquet Direct)
> - **Case sensitivity**: Snowflake identifiers are UPPERCASE—use `PUBLIC.FRUITS`, not `public.fruits`

## Cleanup

To remove all resources created by this demo:

```bash
task cleanup
```

This will prompt for confirmation and then remove:

- The demo database and all its tables
- The service account role
- The external volume (S3 bucket and IAM roles)
- The PAT token and associated policies

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
- Ensure network policies allow your IP (the PAT task restricts to your current public IP)

### "Role not found" errors

Role names with hyphens (`-`) aren't supported. Use underscores instead.

### Can't see tables

Make sure `GRANT SELECT` was run for each table you want to query. The service account role needs explicit access.

### "Table does not exist" but SHOW TABLES works

Snowflake identifiers are **case-sensitive** when querying via DuckDB. Use uppercase:

```sql
-- ❌ Wrong
SELECT * FROM snowflake_catalog.public.fruits;

-- ✅ Correct
SELECT * FROM snowflake_catalog.PUBLIC.FRUITS;
```

## Links

- [Install `snow-bin-utils` (video)](https://youtu.be/zEzf-Rpv8Dc)
- [Horizon Iceberg REST Catalog demo (video)](https://youtu.be/W-kMEGMbS44)
- [Unlock Open Interoperability with Horizon Catalog](https://medium.com/snowflake/unlock-open-interoperability-with-horizon-catalog-89ae67b7ee66) — great intro blog post
- [Horizon Catalog docs](https://docs.snowflake.com/en/user-guide/tables-iceberg-query-using-external-query-engine-snowflake-horizon)
- [Iceberg tables in Snowflake](https://docs.snowflake.com/en/user-guide/tables-iceberg)
- [PAT documentation](https://docs.snowflake.com/en/user-guide/programmatic-access-tokens)
- [snow-bin-utils](https://github.com/kameshsampath/snow-bin-utils)
- [DuckDB Iceberg extension](https://duckdb.org/docs/extensions/iceberg.html)
- [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index)

## License

Copyright 2026 Kamesh Sampath

Licensed under the Apache License 2.0 — see [LICENSE](LICENSE) for details.
