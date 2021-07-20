all: validate_ip create_snowflake_account_objs establish_sf_s3_connectivity create_snowflake_raw_db_objs create_snowflake_curated_db_objs create_snowflake_analytics_db_objs

# fetch inputs from config (json) file
CONFIG_FILE=env/env_example.json
# $(eval [VAR_NAME]=$(shell jq '.Parameters.[VAR_NAME]' ${CONFIG_FILE}))
$(eval PROGRAM=$(shell jq '.Parameters.Program' ${CONFIG_FILE}))
$(eval PROGRAM_LOWER = $(shell echo $(PROGRAM) | tr 'A-Z' 'a-z'))
$(eval PROGRAM_UPPER = $(shell echo $(PROGRAM) | tr 'a-z' 'A-Z'))
$(eval ENV=$(shell jq '.Parameters.Environment' ${CONFIG_FILE}))
$(eval ENV_UPPER=$(shell jq '.Parameters.Environment' ${CONFIG_FILE}))
$(eval AWS_ACCOUNT_ID=$(shell jq '.Parameters.AwsAccountId' ${CONFIG_FILE}))
$(eval SNOWFLAKE_CONN_PROFILE=$(shell jq '.Parameters.SnowflakeParameters.SnowflakeNamedConn' ${CONFIG_FILE}))
$(eval SNOWFLAKE_IAM_ROLE_NAME=$(shell jq '.Parameters.SnowflakeParameters.SnowflakeIAMRoleName' ${CONFIG_FILE}))
$(eval SNOWFLAKE_VPCID=$(shell jq '.Parameters.SnowflakeParameters.SnowflakeVPCID' ${CONFIG_FILE}))
$(eval S3_BUCKET_EG=$(shell jq '.Parameters.AdditionalParameters.S3BucketEg' ${CONFIG_FILE}))
# configure S3_BUCKET_LIST as required. If multiple buckets are required, then list them using a comma delimiter, e.g.: S3_BUCKET_LIST='s3://${S3_BUCKET_EG},s3://${S3_BUCKET_EG2}'
S3_BUCKET_LIST='s3://${S3_BUCKET_EG}'
# standardised Snowflake SnowSQL query format / options
SNOWSQL_QUERY=snowsql -c ${SNOWFLAKE_CONN_PROFILE} -o friendly=false -o header=false -o timing=false
# the variables below are used to validate user input values
CHECK_PROGRAM=$(shell if [[ ${PROGRAM} =~ (_|-| ) ]]; then echo 'invalid'; fi)
CHECK_ENV=$(shell if [[ ${ENV} =~ (_|-| ) ]]; then echo 'invalid'; fi)

deps:
	$(info [+] Install dependencies (snowsql))
	# TODO: prerequisite: need to configure SNOWFLAKE_CONN_PROFILE variable
	brew cask install snowflake-snowsql

validate_ip:
	@if [ ${CHECK_PROGRAM} ];then echo "\nError: Variable 'Program' should be an accronym and not contain spaces, underscores or hyphens. E.g., 'Program': 'EDP'\n"; exit 1; fi
	@if [ ${CHECK_ENV} ];then echo "\nError: Variable 'Environment' should not contain spaces, underscores or hyphens. E.g., 'Environment': 'NP'\n"; exit 1; fi

create_snowflake_account_objs:
	$(info [+] Create the snowflake account objects)
	@[ "${SNOWFLAKE_CONN_PROFILE}" ] || ( echo "\nError: SNOWFLAKE_CONN_PROFILE variable is not set\n"; exit 1 )
	# set the default timezone and timestamp values
	@${SNOWSQL_QUERY} -f set_default_tz_and_ts.sql
	@${SNOWSQL_QUERY} -f account_objects/role/v1_roles.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	# note: part of the script below may not be needed right away. The main purpose of this script is to grant privs to the user 'SNOWFLAKE_PIPELINE_DEPLOYMENT_USER' & any developer users on the project
	@${SNOWSQL_QUERY} -f account_objects/role/permissions/grant_permissions/v1_grant_dba_role.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY} -f account_objects/role/permissions/grant_permissions/create/v1_grant_create_db_and_wh_perms.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY} -f account_objects/resource_monitor/v1_resource_monitors.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY} -f account_objects/role/permissions/grant_permissions/ownership/v1_grant_resource_monitor_ownership_perms.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY} -f account_objects/warehouse/v1_warehouses.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY} -f account_objects/role/permissions/grant_permissions/ownership/v1_grant_wh_ownership_perms.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY} -f account_objects/database/v1_raw_db_and_schemas.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY} -f account_objects/database/v1_curated_db_and_schemas.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY} -f account_objects/database/v1_analytics_db_and_schemas.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY} -f account_objects/role/permissions/grant_permissions/v1_grant_execute_task_perms.sql --variable PROGRAM=${PROGRAM}	--variable ENV=${ENV}
	@${SNOWSQL_QUERY} -f account_objects/role/permissions/grant_permissions/create/v1_grant_create_stage_perms.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY} -f account_objects/role/permissions/v1_create_role_hierarchy.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	# the 3 objects below require a subsequent AWS IAM role to be created (see the Makefile target 'establish_sf_s3_connectivity' below)
	# @${SNOWSQL_QUERY} -f account_objects/storage_integration/v1-create-s3-storage-integration.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV} --variable ENV=${ENV} --variable IAMROLENAME=${SNOWFLAKE_IAM_ROLE_NAME} --variable AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID} --variable ALLOWED_S3_LOCATIONS="${S3_BUCKET_LIST}"
	# @${SNOWSQL_QUERY} -f account_objects/role/permissions/grant_permissions/ownership/v1_grant_storage_int_ownership_perms.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	# @${SNOWSQL_QUERY} -f account_objects/role/permissions/grant_permissions/v1_grant_role_permissions.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}

establish_sf_s3_connectivity:
	$(info [+] Establish connectivity between specified S3 buckets and Snowflake)
	@[ "${SNOWFLAKE_CONN_PROFILE}" ] || ( echo "\nError: SNOWFLAKE_CONN_PROFILE variable is not set\n"; exit 1 )
	cd ../build/snowflake-s3-connectivity/ && make -f setup_sf_connectivity.mk update_s3_bucket_policies CONFIG_FILE=${CONFIG_FILE}
	cd ../build/snowflake-s3-connectivity/ && make -f setup_sf_connectivity.mk create_tmp_snowflake_iam_role CONFIG_FILE=${CONFIG_FILE}
	cd ../build/snowflake-s3-connectivity/ && make -f setup_sf_connectivity.mk create_sf_storage_int_obj CONFIG_FILE=${CONFIG_FILE}
	cd ../build/snowflake-s3-connectivity/ && make -f setup_sf_connectivity.mk create_snowflake_iam_role CONFIG_FILE=${CONFIG_FILE}

create_snowflake_raw_db_objs:
	$(info [+] Create the snowflake RAW db objects)
	@$(eval PROGRAM_LOWER = $(shell echo $(PROGRAM) | tr 'A-Z' 'a-z'))
	@[ "${SNOWFLAKE_CONN_PROFILE}" ] || ( echo "\nError: SNOWFLAKE_CONN_PROFILE variable is not set\n"; exit 1 )
	${SNOWSQL_QUERY} -f database_objects/raw_db/file_format/v1_parquet_file_format.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	${SNOWSQL_QUERY} -f database_objects/raw_db/file_format/v1_csv_file_format.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	${SNOWSQL_QUERY} -f database_objects/raw_db/stage/v1_eg_stage.sql --variable PROGRAM=${PROGRAM_UPPER} --variable ENV=${ENV_UPPER} --variable S3_BUCKET_PATH=${S3_BUCKET_EG}
	${SNOWSQL_QUERY} -f database_objects/raw_db/ext_table/v1_<DATA_SRC>_ext_tbl.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	${SNOWSQL_QUERY} -f database_objects/raw_db/table/v1_etl_control_tbl.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	${SNOWSQL_QUERY} -f database_objects/raw_db/table/<DATA_SRC>/<TBL_TO_LOAD>.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	${SNOWSQL_QUERY} -f database_objects/raw_db/task/v1_<DATA_SRC>_tsk.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}

create_snowflake_curated_db_objs:
	$(info [+] Create the snowflake curated db objects)
	@[ "${SNOWFLAKE_CONN_PROFILE}" ] || ( echo "\nError: SNOWFLAKE_CONN_PROFILE variable is not set\n"; exit 1 )
	${SNOWSQL_QUERY} -f database_objects/curated_db/view/${DATA MODEL OBJS}.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}

create_snowflake_analytics_db_objs:
	$(info [+] Create the snowflake analytics db objects)
	@[ "${SNOWFLAKE_CONN_PROFILE}" ] || ( echo "\nError: SNOWFLAKE_CONN_PROFILE variable is not set\n"; exit 1 )
	${SNOWSQL_QUERY} -f database_objects/analytics_db/view/${REPORTING LAYER OBJS}.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}

# Dev scripts
drop_sf_db_objs:
	$(info [+] Dev purposes: quickly drop all raw/curated/analytics DB objs)
	${SNOWSQL_QUERY} -f dev_scripts/drop_db_objs_struct.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV_UPPER}

dev_skelton_structure:
	${SNOWSQL_QUERY} -f dev_scripts/dev_sf_db_struct/drop_dbs.sql --variable ENV=${ENV_UPPER}
	${SNOWSQL_QUERY} -f dev_scripts/dev_sf_db_struct/create_dev_dbs.sql --variable ENV=${ENV_UPPER}
	${SNOWSQL_QUERY} -f dev_scripts/dev_sf_db_struct/grant_perms.sql --variable ENV=${ENV_UPPER}
	${SNOWSQL_QUERY} -f dev_scripts/dev_sf_db_struct/create_db_objs.sql --variable ENV=${ENV_UPPER}
