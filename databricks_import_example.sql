-- Example usage of catalog_name with IMPORT FOREIGN SCHEMA for Databricks
-- 
-- This demonstrates how to use the new catalog_name option to import 
-- foreign schema from a Databricks catalog

-- First, create a foreign server for Databricks
CREATE SERVER databricks_server 
FOREIGN DATA WRAPPER jdbc_fdw
OPTIONS (
    drivername 'com.databricks.client.jdbc.Driver',
    url 'jdbc:databricks://your-workspace.cloud.databricks.com:443/default;transportMode=http;ssl=1;httpPath=/sql/1.0/endpoints/your-endpoint-id',
    jarfile '/path/to/DatabricksJDBC42.jar'
);

-- Create user mapping
CREATE USER MAPPING FOR current_user
SERVER databricks_server
OPTIONS (
    username 'token',
    password 'your-databricks-token'
);

-- Import foreign schema with catalog_name option
-- This will import all tables from the specified catalog and schema
IMPORT FOREIGN SCHEMA "my_schema" 
FROM SERVER databricks_server 
INTO local_schema 
OPTIONS (
    catalog_name 'production_catalog'
);

-- You can also use the recreate option to drop and recreate tables
IMPORT FOREIGN SCHEMA "sales" 
FROM SERVER databricks_server 
INTO sales_local 
OPTIONS (
    catalog_name 'analytics_catalog',
    recreate 'true'
);

-- The above will generate CREATE FOREIGN TABLE statements like:
-- CREATE FOREIGN TABLE sales_local.customers(
--     id BIGINT,
--     name TEXT,
--     email TEXT,
--     created_at TIMESTAMP
-- ) SERVER databricks_server 
-- OPTIONS (
--     catalog_name 'analytics_catalog',
--     schema_name 'sales',
--     table_name 'customers'
-- );