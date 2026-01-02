-- Query Snowflake Iceberg tables with DuckDB via Horizon Catalog
--
-- Usage: 
--   source .env && envsubst < demo.sql | duckdb
--
-- Or manually replace $DEMO_DATABASE, $SNOWFLAKE_ACCOUNT_URL, and $SA_ROLE

INSTALL iceberg;
INSTALL httpfs;
LOAD iceberg;
LOAD httpfs;

-- Create secret for PAT authentication
CREATE OR REPLACE SECRET snowflake_secret ( 
    TYPE iceberg, 
    CLIENT_ID '',
    CLIENT_SECRET getenv('SNOWFLAKE_PASSWORD'),
    OAUTH2_SERVER_URI '$SNOWFLAKE_ACCOUNT_URL/polaris/api/catalog/v1/oauth/tokens',
    OAUTH2_GRANT_TYPE 'client_credentials',
    OAUTH2_SCOPE 'session:role:$SA_ROLE'
);

-- Attach to Snowflake database via Horizon Catalog
ATTACH '$DEMO_DATABASE' AS snowflake_catalog (
    TYPE iceberg,
    SECRET snowflake_secret,
    ENDPOINT '$SNOWFLAKE_ACCOUNT_URL/polaris/api/catalog'
);

-- List all available tables
SHOW ALL TABLES;

-- Example query (uncomment and modify):
-- SELECT * FROM snowflake_catalog.PUBLIC.fruits LIMIT 10;
