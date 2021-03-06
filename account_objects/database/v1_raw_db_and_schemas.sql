!SET variable_substitution=true;
/*
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE &{PROGRAM}_&{ENV}_DEVELOPER_WH;
DROP DATABASE IF EXISTS &{PROGRAM}_&{ENV}_RAW_DB;
*/

USE ROLE &{PROGRAM}_&{ENV}_DBA;
USE WAREHOUSE &{PROGRAM}_&{ENV}_DEVELOPER_WH;

--create raw_db structure
CREATE DATABASE IF NOT EXISTS &{PROGRAM}_&{ENV}_RAW_DB COMMENT = 'Ingestion / landing area, containing raw, non-transformed source system data';
CREATE SCHEMA IF NOT EXISTS &{PROGRAM}_&{ENV}_RAW_DB.&{DATA_SRC1} WITH MANAGED ACCESS COMMENT = 'Contains tables/data from &{DATA_SRC1} data';
CREATE SCHEMA IF NOT EXISTS &{PROGRAM}_&{ENV}_RAW_DB.&{DATA_SRC2} WITH MANAGED ACCESS COMMENT = 'Contains tables/data from &{DATA_SRC2} data';
CREATE SCHEMA IF NOT EXISTS &{PROGRAM}_&{ENV}_RAW_DB.UTILITIES WITH MANAGED ACCESS COMMENT = 'Contains all database objects other than tables or views';
DROP SCHEMA IF EXISTS &{PROGRAM}_&{ENV}_RAW_DB.PUBLIC;
