!SET variable_substitution=true;
USE ROLE SECURITYADMIN;
GRANT ROLE &{PROGRAM}_&{ENV}_DBA TO USER &{dba_user};
GRANT ROLE &{PROGRAM}_&{ENV}_DBT_SVC TO USER &{dba_user};
--GRANT ROLE ACCOUNTADMIN TO USER &{PROGRAM}_&{ENV}_SNOWFLAKE_PIPELINE_DEPLOYMENT_USER;
