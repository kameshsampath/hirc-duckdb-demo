--!jinja
use role accountadmin;
GRANT USAGE ON DATABASE {{database_name}} TO ROLE {{sa_role}};
GRANT USAGE ON SCHEMA {{database_name}}.{{schema}} TO ROLE {{sa_role}};
GRANT SELECT ON TABLE {{database_name}}.{{schema}}.{{table}} 
TO ROLE {{sa_role}};