!SET variable_substitution=true;
USE ROLE ACCOUNTADMIN;
GRANT CREATE STAGE ON SCHEMA &{PROGRAM}_&{ENV}_RAW_DB.UTILITIES TO ROLE &{PROGRAM}_&{ENV}_SF_STAGE_ADMIN;
