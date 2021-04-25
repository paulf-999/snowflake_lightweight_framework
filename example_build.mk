default: create_snowflake_account_objs establish_sf_s3_connectivity create_snowflake_raw_db_objs create_snowflake_curated_db_objs create_snowflake_analytics_db_objs

# fetch inputs from config (json) file
SNOWFLAKE_CONN_PROFILE=#
CONFIG_FILE=env/config_example.json
#$(eval [VAR_NAME]=$(shell jq '.Parameters.[VAR_NAME]' ${CONFIG_FILE}))
$(eval PROGRAM=$(shell jq '.Parameters.Program' ${CONFIG_FILE}))
$(eval PROGRAM_LOWER = $(shell echo $(PROGRAM) | tr 'A-Z' 'a-z'))
$(eval ENV=$(shell jq '.Parameters.Environment' ${CONFIG_FILE}))
$(eval STAGE=$(shell jq '.Parameters.Stage' ${CONFIG_FILE}))
$(eval BRANCH=$(shell jq '.Parameters.Branch' ${CONFIG_FILE}))
$(eval AWS_ACCOUNT_ID=$(shell jq '.Parameters.AwsAccountId' ${CONFIG_FILE}))
$(eval SNOWFLAKE_VPCID=$(shell jq '.Parameters.SnowflakeParameters.SnowflakeVPCID' ${CONFIG_FILE}))
$(eval SNOWFLAKE_IAM_ROLE_NAME=$(shell jq '.Parameters.SnowflakeParameters.SnowflakeIAMRoleName' ${CONFIG_FILE}))
$(eval SNOWSQL_QUERY_OPTS=$(shell jq '.Parameters.SnowflakeParameters.SnowSqlQueryTemplate' ${CONFIG_FILE}))
$(eval S3_BUCKET=$(shell jq '.Parameters.AdditionalParameters.S3Bucket' ${CONFIG_FILE}))
#configure below as required
S3_BUCKET_LIST='s3://${S3_BUCKET}'

deps:
	$(info [+] Install dependencies (snowsql))
	# need to source your bash_profile, post-install
	brew cask install snowflake-snowsql && . ~/.bash_profile
	# set the default timezone and timestamp values
	@${SNOWSQL_QUERY_OPTS} -f set_default_tz_and_ts.sql

create_snowflake_account_objs:
	$(info [+] Create the snowflake account objects)
	@[ "${SNOWFLAKE_CONN_PROFILE}" ] || ( echo "\nError: SNOWFLAKE_CONN_PROFILE variable is not set\n"; exit 1 )
	@${SNOWSQL_QUERY_OPTS} -f account_objects/role/v1_roles.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY_OPTS} -f account_objects/role/permissions/grant_permissions/v1_grant_dba_role.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY_OPTS} -f account_objects/role/permissions/grant_permissions/create/v1_grant_create_db_and_wh_perms.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY_OPTS} -f account_objects/resource_monitor/v1_resource_monitors.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY_OPTS} -f account_objects/role/permissions/grant_permissions/ownership/v1_grant_resource_monitor_ownership_perms.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY_OPTS} -f account_objects/warehouse/v1_warehouses.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY_OPTS} -f account_objects/role/permissions/grant_permissions/ownership/v1_grant_wh_ownership_perms.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY_OPTS} -f account_objects/database/v1_raw_db_and_schemas.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV} 
	@${SNOWSQL_QUERY_OPTS} -f account_objects/database/v1_curated_db_and_schemas.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY_OPTS} -f account_objects/database/v1_analytics_db_and_schemas.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY_OPTS} -f account_objects/role/permissions/grant_permissions/v1_grant_execute_task_perms.sql --variable PROGRAM=${PROGRAM}	--variable ENV=${ENV}
	@${SNOWSQL_QUERY_OPTS} -f account_objects/role/permissions/grant_permissions/create/v1_grant_create_stage_perms.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY_OPTS} -f account_objects/role/permissions/v1_create_role_hierarchy.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	#the 2 objects below require a subsequent AWS IAM role to be created (see 'establish_sf_s3_connectivity' below)
	@${SNOWSQL_QUERY_OPTS} -f account_objects/storage_integration/v1-create-s3-storage-integration.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV} --variable ENV=${ENV} --variable IAMROLENAME=${SNOWFLAKE_IAM_ROLE_NAME} --variable AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID} --variable ALLOWED_S3_LOCATIONS="${S3_BUCKET_LIST}"
	@${SNOWSQL_QUERY_OPTS} -f account_objects/role/permissions/grant_permissions/ownership/v1_grant_storage_int_ownership_perms.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	@${SNOWSQL_QUERY_OPTS} -f account_objects/role/permissions/grant_permissions/v1_grant_role_permissions.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}

establish_sf_s3_connectivity:
	$(info [+] Establishes connectivity between specified S3 buckets and Snowflake)
	@[ "${SNOWFLAKE_CONN_PROFILE}" ] || ( echo "\nError: SNOWFLAKE_CONN_PROFILE variable is not set\n"; exit 1 )
	cd ../build/snowflake-s3-connectivity/ && make -f setup_sf_connectivity.mk update_s3_bucket_policies CONFIG_FILE=${CONFIG_FILE}
	cd ../build/snowflake-s3-connectivity/ && make -f setup_sf_connectivity.mk create_tmp_snowflake_iam_role CONFIG_FILE=${CONFIG_FILE}
	cd ../build/snowflake-s3-connectivity/ && make -f setup_sf_connectivity.mk create_sf_storage_int_obj CONFIG_FILE=${CONFIG_FILE}
	cd ../build/snowflake-s3-connectivity/ && make -f setup_sf_connectivity.mk create_snowflake_iam_role CONFIG_FILE=${CONFIG_FILE}

create_snowflake_raw_db_objs:
	$(info [+] Create the snowflake RAW db objects)
	@$(eval PROGRAM_LOWER = $(shell echo $(PROGRAM) | tr 'A-Z' 'a-z'))
	@[ "${SNOWFLAKE_CONN_PROFILE}" ] || ( echo "\nError: SNOWFLAKE_CONN_PROFILE variable is not set\n"; exit 1 )
	${SNOWSQL_QUERY_OPTS} -f database_objects/raw_db/file_format/v1_parquet_file_format.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	${SNOWSQL_QUERY_OPTS} -f database_objects/raw_db/file_format/v1_csv_file_format.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	${SNOWSQL_QUERY_OPTS} -f database_objects/raw_db/stage/v1_${DATA_SRC}_stage.sql --variable PROGRAM=${PROGRAM_LOWER} --variable ENV=${ENV} --variable AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID} --variable STAGE=${STAGE} --variable BRANCH=${BRANCH}
	${SNOWSQL_QUERY_OPTS} -f database_objects/raw_db/ext_table/v1_${DATA_SRC}_ext_tbl.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	${SNOWSQL_QUERY_OPTS} -f database_objects/raw_db/table/v1_etl_control_tbl.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	${SNOWSQL_QUERY_OPTS} -f database_objects/raw_db/table/nexus/tmp/v1_customer.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	${SNOWSQL_QUERY_OPTS} -f database_objects/raw_db/table/${DATA_SRC}/${TABLE_TO_LOAD}.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	${SNOWSQL_QUERY_OPTS} -f database_objects/raw_db/task/v1_${DATA_SRC}_tsk.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}
	
create_snowflake_curated_db_objs:
	$(info [+] Create the snowflake curated db objects)
	@[ "${SNOWFLAKE_CONN_PROFILE}" ] || ( echo "\nError: SNOWFLAKE_CONN_PROFILE variable is not set\n"; exit 1 )
	${SNOWSQL_QUERY_OPTS} -f database_objects/curated_db/view/${DATA MODEL OBJS}.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}

create_snowflake_analytics_db_objs:
	$(info [+] Create the snowflake analytics db objects)
	@[ "${SNOWFLAKE_CONN_PROFILE}" ] || ( echo "\nError: SNOWFLAKE_CONN_PROFILE variable is not set\n"; exit 1 )
	${SNOWSQL_QUERY_OPTS} -f database_objects/analytics_db/view/${REPORTING LAYER OBJS}.sql --variable PROGRAM=${PROGRAM} --variable ENV=${ENV}

# Dev scripts
drop_sf_db_objs:
	$(info [+] Dev purposes: quickly drop all raw/curated/analytics DB objs)
	${SNOWSQL_QUERY_OPTS} -f dev_scripts/drop_db_objs_struct.sql --variable PROGRAM=${PROGRAM} --variable ENV=${STAGE}

dev_skelton_structure:
	${SNOWSQL_QUERY_OPTS} -f dev_scripts/dev_sf_db_struct/drop_dbs.sql --variable ENV=${STAGE}
	${SNOWSQL_QUERY_OPTS} -f dev_scripts/dev_sf_db_struct/create_dev_dbs.sql --variable ENV=${STAGE}
	${SNOWSQL_QUERY_OPTS} -f dev_scripts/dev_sf_db_struct/grant_perms.sql --variable ENV=${STAGE}
	${SNOWSQL_QUERY_OPTS} -f dev_scripts/dev_sf_db_struct/create_db_objs.sql --variable ENV=${STAGE}
	