--!jinja
use role accountadmin;
GRANT SELECT ON TABLE {{database_name}}.{{schema}}.{{table}} 
TO ROLE {{sa_role}};