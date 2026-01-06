--!jinja
-- Cleanup all resources created by this demo
-- 
-- Usage:
--   snow sql -f cleanup.sql \
--     --enable-templating ALL \
--     --variable database_name=$DEMO_DATABASE \
--     --variable sa_role=$SA_ROLE \
--     --variable sa_user=$SA_USER
--
-- WARNING: This will permanently delete all demo resources!

USE ROLE accountadmin;

-- Drop the demo database (includes all schemas and tables)
DROP DATABASE IF EXISTS {{database_name}};

-- Drop the service account role
DROP ROLE IF EXISTS {{sa_role}};

-- Optionally drop the service account user (uncomment if you created one just for this demo)
-- DROP USER IF EXISTS {{sa_user}};

-- Note: External volume and PAT are cleaned up via snow-utils commands in the Taskfile
-- Run: task cleanup (to clean everything including external volume and PAT)

SELECT 'SQL cleanup complete! Dropped database {{database_name}} and role {{sa_role}}' AS status;

