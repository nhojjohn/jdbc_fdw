-- Example SQL demonstrating catalog_name option usage
-- This file shows how to use the new catalog_name option alongside
-- existing schema_name and table_name options

-- 1. Basic usage with just catalog_name
CREATE FOREIGN TABLE catalog_only_table (
    id INTEGER,
    name TEXT
) SERVER my_jdbc_server
OPTIONS (
    catalog_name 'production'
);
-- This maps to: production..table_name (catalog.schema.table where schema is default)

-- 2. Using catalog_name with schema_name
CREATE FOREIGN TABLE catalog_schema_table (
    id INTEGER,
    name TEXT,
    created_date DATE
) SERVER my_jdbc_server
OPTIONS (
    catalog_name 'production',
    schema_name 'sales'
);
-- This maps to: production.sales.table_name

-- 3. Full three-part naming with all options
CREATE FOREIGN TABLE full_mapping_table (
    customer_id INTEGER,
    customer_name TEXT,
    email TEXT,
    phone TEXT
) SERVER my_jdbc_server
OPTIONS (
    catalog_name 'production',
    schema_name 'crm',
    table_name 'customer_master'
);
-- This maps to: production.crm.customer_master

-- 4. Using only schema_name and table_name (existing functionality)
CREATE FOREIGN TABLE schema_table_only (
    id INTEGER,
    description TEXT
) SERVER my_jdbc_server
OPTIONS (
    schema_name 'inventory',
    table_name 'products'
);
-- This maps to: inventory.products (no catalog specified)

-- 5. IMPORT FOREIGN SCHEMA with catalog_name option (NEW FEATURE)
-- This imports all tables from a specific catalog and schema
IMPORT FOREIGN SCHEMA "sales_data" 
FROM SERVER my_jdbc_server 
INTO imported_sales 
OPTIONS (
    catalog_name 'production_catalog'
);

-- 6. IMPORT FOREIGN SCHEMA with catalog_name and recreate option
IMPORT FOREIGN SCHEMA "analytics" 
FROM SERVER my_jdbc_server 
INTO analytics_local 
OPTIONS (
    catalog_name 'data_warehouse',
    recreate 'true'
);

-- The above IMPORT statements will generate CREATE FOREIGN TABLE commands like:
-- CREATE FOREIGN TABLE imported_sales.table1(
--     id INTEGER,
--     name TEXT
-- ) SERVER my_jdbc_server 
-- OPTIONS (
--     catalog_name 'production_catalog',
--     schema_name 'sales_data'
-- );

-- 5. Using only table_name (existing functionality)
CREATE FOREIGN TABLE table_only (
    id INTEGER,
    value TEXT
) SERVER my_jdbc_server
OPTIONS (
    table_name 'remote_table'
);
-- This maps to: remote_table (no catalog or schema specified)

-- Note: The options work in combination:
-- - catalog_name: Specifies the catalog (database) name
-- - schema_name: Specifies the schema name within the catalog
-- - table_name: Specifies the actual table name
-- 
-- If not specified, defaults will be used by the JDBC driver.
-- The final format will be: catalog.schema.table
-- where missing components use driver defaults.