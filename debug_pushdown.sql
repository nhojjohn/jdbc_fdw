-- Debug script to check aggregate pushdown behavior

-- Enable detailed query logging
SET log_statement = 'all';
SET log_min_messages = 'debug1';
SET client_min_messages = 'debug1';

-- Check if there are any WHERE conditions on your table
-- Even conditions from views, RLS policies, or column constraints can block pushdown
EXPLAIN (VERBOSE, FORMAT TEXT) 
SELECT count(target_id) FROM your_foreign_table;

-- Also test with explicit simple query to confirm COUNT works when no conditions exist
EXPLAIN (VERBOSE, FORMAT TEXT)
SELECT count(*) FROM your_foreign_table;

-- Check for any active row-level security policies
SELECT schemaname, tablename, policyname, cmd, qual 
FROM pg_policies 
WHERE tablename = 'your_foreign_table';

-- Check table constraints that might add implicit conditions
SELECT conname, contype, consrc 
FROM pg_constraint c
JOIN pg_class t ON c.conrelid = t.oid  
WHERE t.relname = 'your_foreign_table';

-- Check target_id column properties that might affect pushdown
SELECT 
    a.attname,
    t.typname,
    a.atttypmod,
    a.attnotnull,
    a.atthasdef,
    col.collname,
    a.attcollation
FROM pg_attribute a
JOIN pg_class c ON a.attrelid = c.oid
JOIN pg_type t ON a.atttypid = t.oid
LEFT JOIN pg_collation col ON a.attcollation = col.oid
WHERE c.relname = 'your_foreign_table' 
AND a.attname = 'target_id'
AND a.attnum > 0;

-- Compare with a working column - check if other columns behave the same
EXPLAIN (VERBOSE, FORMAT TEXT)
SELECT count(source_id) FROM your_foreign_table;

-- Test if NULL handling is the issue
EXPLAIN (VERBOSE, FORMAT TEXT)  
SELECT count(target_id) FROM your_foreign_table WHERE target_id IS NOT NULL;

-- Test different column types to identify the pattern
EXPLAIN (VERBOSE, FORMAT TEXT)
SELECT count(created_at) FROM your_foreign_table;

-- Check if the issue affects all text columns
SELECT 
    a.attname,
    t.typname,
    a.attcollation,
    col.collname
FROM pg_attribute a
JOIN pg_class c ON a.attrelid = c.oid
JOIN pg_type t ON a.atttypid = t.oid
LEFT JOIN pg_collation col ON a.attcollation = col.oid
WHERE c.relname = 'your_foreign_table' 
AND a.attnum > 0
AND t.typname IN ('text', 'varchar', 'char', 'int4', 'int8', 'timestamp', 'timestamptz')
ORDER BY a.attnum;

-- Test COUNT on a numeric column (should work)
-- First find a numeric column:
SELECT a.attname, t.typname 
FROM pg_attribute a
JOIN pg_class c ON a.attrelid = c.oid
JOIN pg_type t ON a.atttypid = t.oid
WHERE c.relname = 'your_foreign_table' 
AND a.attnum > 0
AND t.typname IN ('int4', 'int8', 'numeric', 'float4', 'float8')
LIMIT 3;

-- Test if ALL text columns fail pushdown (should confirm the pattern)
EXPLAIN (VERBOSE, FORMAT TEXT)
SELECT count(source_id) FROM your_foreign_table;

EXPLAIN (VERBOSE, FORMAT TEXT)
SELECT count(producer) FROM your_foreign_table;

-- Confirm timestamp columns work
EXPLAIN (VERBOSE, FORMAT TEXT)  
SELECT count(relationship_timestamp) FROM your_foreign_table;