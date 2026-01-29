# Catalog Name Support for IMPORT FOREIGN SCHEMA

This enhancement adds support for the `catalog_name` option in the IMPORT FOREIGN SCHEMA statement to work with Databricks and other databases that use three-part naming (catalog.schema.table).

## Changes Made

### 1. Core Implementation Files

#### jdbc_fdw.c
- Modified `jdbcImportForeignSchema()` function to:
  - Parse the new `catalog_name` option from IMPORT FOREIGN SCHEMA statement
  - Pass catalog and schema parameters to the new catalog-aware functions
  - Generate CREATE FOREIGN TABLE statements with catalog_name and schema_name options

#### jq.h
- Added function declaration: `jq_get_schema_info_with_catalog()`

#### jq.c
- Added three new catalog-aware functions:
  - `jq_get_table_names_with_catalog()` - Gets table names from specified catalog and schema
  - `jq_get_column_infos_with_catalog()` - Gets column information with catalog and schema context  
  - `jq_get_schema_info_with_catalog()` - Main function that orchestrates the schema import

#### option.c
- The `catalog_name` option was already defined for `ForeignTableRelationId`

### 2. Java Side (JDBCUtils.java)
The Java implementation already supports catalog and schema parameters in methods:
- `getTableNames(String catalog, String schema)`
- `getColumnNames(String catalog, String schema, String tableName)`
- `getColumnTypes(String catalog, String schema, String tableName)`
- `getPrimaryKey(String catalog, String schema, String tableName)`

## Usage

### Basic Usage with Databricks

```sql
-- Create foreign server for Databricks
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

-- Import schema with catalog_name option
IMPORT FOREIGN SCHEMA "sales_schema" 
FROM SERVER databricks_server 
INTO local_sales 
OPTIONS (
    catalog_name 'production_catalog'
);
```

### Advanced Usage with Options

```sql
-- Import with recreate option (drop and recreate existing tables)
IMPORT FOREIGN SCHEMA "analytics_schema" 
FROM SERVER databricks_server 
INTO analytics_local 
OPTIONS (
    catalog_name 'data_warehouse',
    recreate 'true'
);
```

### Generated Foreign Tables

The IMPORT FOREIGN SCHEMA statement will generate CREATE FOREIGN TABLE statements like:

```sql
CREATE FOREIGN TABLE local_sales.customers(
    customer_id BIGINT,
    customer_name TEXT,
    email TEXT,
    created_date TIMESTAMP
) SERVER databricks_server 
OPTIONS (
    catalog_name 'production_catalog',
    schema_name 'sales_schema'
);
```

## Benefits

1. **Databricks Compatibility**: Works seamlessly with Databricks three-part naming convention
2. **Flexible Schema Import**: Can import from specific catalogs and schemas
3. **Backward Compatibility**: Existing functionality without catalog_name continues to work
4. **Proper Table Generation**: Generated foreign tables include necessary options for proper data access

## Implementation Details

### Function Call Flow

1. `IMPORT FOREIGN SCHEMA` with `catalog_name` option
2. `jdbcImportForeignSchema()` parses the option
3. `jq_get_schema_info_with_catalog()` is called with catalog and schema parameters
4. `jq_get_table_names_with_catalog()` gets table list from JDBC metadata
5. For each table, `jq_get_column_infos_with_catalog()` gets column metadata
6. CREATE FOREIGN TABLE statements are generated with proper OPTIONS clause

### Error Handling

- Validates that required Java methods exist
- Proper cleanup of Java string references
- Error reporting for missing methods or failed connections

### Memory Management

- Proper cleanup of JNI local references
- PostgreSQL memory context management for allocated structures

## Testing

Test the functionality with:

```sql
-- Test basic import
IMPORT FOREIGN SCHEMA "test_schema" 
FROM SERVER your_server 
INTO test_local 
OPTIONS (catalog_name 'test_catalog');

-- Verify generated tables
\d+ test_local.*
```

## Compatibility

- Works with PostgreSQL 13.15+ through 18.1+
- Compatible with existing jdbc_fdw installations
- Requires Databricks JDBC driver for Databricks usage
- Backward compatible with existing IMPORT FOREIGN SCHEMA usage