## Snowflake Lightweight Framework

Lightweight cookie-cutter framework to quickly create the below Snowflake architecture.

![image info](pictures/snowflake-framework-architecture.png)


### High-level summary

The framework consists of using a `makefile` to orchestrate the execution of `snowsql` commands. Where:

* the input `makefile` used is `example_build.mk`
* and the input args for the `makefile` come from `env/config_example.json`

Where the framework:

1) Creates account objects needed to support the above architecture, including:
* Databases for each of the zones highlighted above (raw, curated, analytics)
* A custom role hierarchy (shown below), to exercise RBAC across all of the account/database objects created
* Corresponding warehouses, resource monitors and 'custom admin-roles', to own account-level operations, e.g. to create a Snowflake Task, Storage Integration object etc.
2) Creates database objects needed to support the above architecture.
(more to follow.)

![image info](pictures/snowflake-role-hierarchy.png)

### How-to run:

As this is a cookie cutter solution, the steps involved in building and executing involve:

1) Updating the input parameters within `env/config_example.json`
2) Within `example_build.mk`

The main execution is carried out within `example_build.mk`, where inputs are read in from the file `env/config_example.json`.
