!SET variable_substitution=true;
USE ROLE SECURITYADMIN;

CREATE USER IF NOT EXISTS &{PROGRAM}_SNOWFLAKE_PIPELINE_DEPLOYMENT_USER
    LOGIN_NAME = '&{PROGRAM}_SNOWFLAKE_PIPELINE_DEPLOYMENT_USER'
    PASSWORD = 'TmpP455'
    DISPLAY_NAME = 'Eg Developer User'
    DEFAULT_ROLE = SYSADMIN
    DEFAULT_WAREHOUSE = &{PROGRAM}_&{ENV}_DEVELOPER_WH
    MUST_CHANGE_PASSWORD = TRUE;
