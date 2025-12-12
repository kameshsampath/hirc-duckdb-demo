SET enable_http_logging = true;

INSTALL iceberg;
INSTALL httpfs;
LOAD iceberg;
LOAD httpfs;

SET VARIABLE pat_token = getenv('SNOWFLAKE_PASSWORD');
SET VARIABLE catalog_uri = getenv('SNOWFLAKE_ACCOUNT_URL') || '/polaris/api/catalog';
SET VARIABLE oauth2_server_uri = getvariable('catalog_uri') || '/v1/oauth/tokens';
SET VARIABLE oauth_scope = 'session:role:' || getenv('SA_ROLE');

-- || getenv('SA_ROLE');

CREATE OR REPLACE SECRET snowflake_secret ( 
    TYPE iceberg, 
    CLIENT_ID '',
    CLIENT_SECRET getvariable('pat_token'),
    OAUTH2_SERVER_URI getvariable('oauth2_server_uri'),
    OAUTH2_GRANT_TYPE 'client_credentials',
    OAUTH2_SCOPE getvariable('oauth_scope')
);

-- Note: Run this file using: duckdb -bail -c ".read demo.sql" or use envsubst
-- The ATTACH statement requires a literal string, so we use shell substitution

ATTACH 'KAMESHS_DUCKDB_ICEBERG_DEMO' AS snowflake_catalog (
    TYPE iceberg,
    SECRET snowflake_secret,
    ENDPOINT getvariable('catalog_uri')
);

SHOW ALL TABLES;