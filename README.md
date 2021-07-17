## Snowflake Lightweight Framework

Cookie-cutter framework to quickly create a lightweight Snowflake architecture.

### High-level summary

The framework consists of using a `makefile` to orchestrate the execution of `snowsql` commands. Where:

* the input args for the `makefile` come from `env/config_example.json`

![image info](pictures/snowflake-framework-architecture.png)

The main execution steps are as follows:

1) Creates account objects needed to support the above architecture, including:
    * Databases for each of the zones highlighted above (raw, curated, analytics)
    * A custom role hierarchy (shown below), to exercise RBAC across all of the account/database objects created
    * Corresponding warehouses, resource monitors and 'custom admin-roles', to own account-level operations, e.g. to create a Snowflake Task, Storage Integration object etc.
2) Create database objects needed to support the above architecture (more to follow.)

![image info](pictures/snowflake-role-hierarchy.png)

### Prerequisites:

1) You'll need to create a SnowSQL 'named profile', used to store the credentials used to connect to your Snowflake cluster. Following this, update the value of the variable ${SNOWFLAKE_CONN_PROFILE} to the name you've used for your connection profile
2) If you're looking to make use of CI/CD activities, you'll need to create a corresponding user the the CI/CD pipelines to use. The templated SQL script to create this user can be found within: `account_objects/user/v1_create_pipeline_deploy_user.sql`
### How-to run:

The steps involved in building and executing involve:

1) Updating the input parameters within `env/config_example.json`
2) and running `make`!
