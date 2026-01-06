--!jinja
USE ROLE accountadmin;
CREATE OR REPLACE ROLE {{sa_role}};

GRANT ROLE {{sa_role}} TO USER {{snowflake_user}};

CREATE OR REPLACE DATABASE {{database_name}};
GRANT USAGE ON DATABASE {{database_name}} TO ROLE {{sa_role}};

ALTER DATABASE IF EXISTS {{database_name}}
   SET EXTERNAL_VOLUME={{external_volume_name}};