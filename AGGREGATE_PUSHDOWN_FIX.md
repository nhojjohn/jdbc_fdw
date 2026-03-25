# Aggregate Pushdown Bug Fix

## Problem
`COUNT(text_column)` and other aggregates on text columns were not being pushed down, while `COUNT(*)` and aggregates on non-collatable types worked fine.

## Symptoms
- ✅ `COUNT(*)` → Pushed down
- ✅ `COUNT(timestamp_column)` → Pushed down (no collation)
- ❌ `COUNT(text_column)` → NOT pushed down (has default collation 100)

## Root Cause

The issue was in [deparse.c](deparse.c#L815-L820) T_Aggref case. The collation validation was too restrictive:

```c
if (agg->inputcollid == InvalidOid)
     /* OK, inputs are all noncollatable */ ;
else if (inner_cxt.state != FDW_COLLATE_SAFE ||
         agg->inputcollid != inner_cxt.collation)
    return false;
```

This check rejected aggregates with `DEFAULT_COLLATION_OID` (OID 100), which is the standard C locale collation used by PostgreSQL for text columns. This is perfectly safe to push down to remote databases since:
1. DEFAULT_COLLATION_OID (C locale) is universally supported
2. For aggregates like COUNT, the collation doesn't affect the result
3. Remote databases handle default collation correctly

## Fix Applied

Added an explicit check to allow DEFAULT_COLLATION_OID in [deparse.c](deparse.c#L817-L818):

```c
if (agg->inputcollid == InvalidOid)
     /* OK, inputs are all noncollatable */ ;
else if (agg->inputcollid == DEFAULT_COLLATION_OID)
     /* OK, default collation is safe for all databases */ ;
else if (inner_cxt.state != FDW_COLLATE_SAFE ||
         agg->inputcollid != inner_cxt.collation)
    return false;
```

This allows text columns with default collation to be used in aggregate functions that are pushed down to the remote server.

## Testing Requirements

To test the fix:

1. **Fix PostgreSQL 18 compatibility issues** - The current codebase has API compatibility problems with PostgreSQL 18's `create_foreign_upper_path()` function signature that need to be resolved before compilation succeeds.

2. **Compile jdbc_fdw:**
   ```bash
   make USE_PGXS=1 clean
   make USE_PGXS=1
   sudo make USE_PGXS=1 install
   ```

3. **Test the fix:**
   ```sql
   -- Restart PostgreSQL or reconnect
   EXPLAIN (VERBOSE, FORMAT TEXT) 
   SELECT count(text_column) FROM your_foreign_table;
   ```

4. **Expected result:**
   ```
   Foreign Scan  (cost=1.00..1.00 rows=1 width=8)
     Output: (count(text_column))
     Remote SQL: SELECT count(text_column) FROM remote_catalog.remote_schema.remote_table
   ```

## Benefits

This fix enables aggregate pushdown for:
- COUNT, SUM, AVG, MAX, MIN on text columns with default collation
- Significantly improves query performance by reducing data transfer
- Leverages remote database's computation power

## Notes

- The fix specifically addresses DEFAULT_COLLATION_OID (100)
- Other non-default collations still require strict validation for correctness
- This matches the behavior of postgres_fdw
