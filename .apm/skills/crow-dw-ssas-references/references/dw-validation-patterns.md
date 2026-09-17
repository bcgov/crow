<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# DW Validation Patterns

T-SQL validation and data quality query patterns for post-load reconciliation and smoke testing of data warehouse artifacts. Use these patterns when reviewing or generating DW schemas, ELT pipelines, and orchestrated builds.

Org conventions used in examples:

- Schemas: `Dimension`, `Fact`, `Staging`, `Internal`, `SSAS`, `Security`, `Snapshots`
- No table prefixes: `Dimension.Customer`, not `DimCustomer`
- Surrogate key: `{EntityName}Key`; natural key: `_Source{OriginalName}`
- Date dimension: `Dimension.Calendar`; semantic table: `Calendar`
- Audit: `Internal.Lineage` plus `LineageKey` on staging tables
- Load stored procedures: `Schema.Load{Entity}`
- Environments: DEV, TEST, UAT, PROD, SUPPORT

## 1. Staging Validation

Run these checks after the SSIS staging load completes and before executing dimension or fact load stored procedures.

### 1a. Row Count Reconciliation

Compare staging row count to the source row count for the incremental load window.

```sql
-- Run in the staging database after Load_Staging.dtsx completes.
SELECT 
    'Staging.{EntityName}' AS Target,
    COUNT(*) AS StagingRows,
    MAX(LineageKey) AS LineageKey
FROM [Staging].[{EntityName}];
```

Expected result: staging count matches the source extract count for the same load window.

### 1b. Duplicate Natural Keys in Staging

Duplicate natural keys usually indicate a source primary key change, an extract defect, or a missing deduplication rule.

```sql
SELECT [_Source{EntityID}], COUNT(*) AS Cnt
FROM [Staging].[{EntityName}]
GROUP BY [_Source{EntityID}]
HAVING COUNT(*) > 1;
```

Expected result: 0 rows. Any rows are a CRITICAL finding.

### 1c. NULL Natural Keys

```sql
SELECT COUNT(*) AS NullNaturalKeys
FROM [Staging].[{EntityName}]
WHERE [_Source{EntityID}] IS NULL;
```

Expected result: 0 rows.

### 1d. LineageKey Assigned

```sql
SELECT COUNT(*) AS MissingLineageKey
FROM [Staging].[{EntityName}]
WHERE LineageKey IS NULL;
```

Expected result: 0 rows. A NULL `LineageKey` means the SSIS package did not assign audit lineage.

## 2. Dimension Validation

Run these checks after executing `Dimension.Load{Entity}`.

### 2a. Unknown Member Row

Every dimension must include exactly **one** unknown member row with `{EntityName}Key = -1`. This is the org standard (single sentinel, not multiple -2/-3 variants).

```sql
SELECT COUNT(*) AS UnknownMemberExists
FROM [Dimension].[{EntityName}]
WHERE [{EntityName}Key] = -1;
```

Expected result: 1. Missing unknown member is a CRITICAL finding — orphan fact rows have no safe fallback.

> **Date dimension sentinel:** `Dimension.Calendar` uses `DATE` type FK, not INT. The sentinel date key is `'1753-01-01'` (not -1). Verify with:
> ```sql
> SELECT COUNT(*) AS SentinelExists FROM [Dimension].[Calendar] WHERE [Date Key] = '1753-01-01';
> -- Expected: 1
> ```
> The SSAS view (`SSAS.v_Calendar`) filters this row out — it exists only for SQL FK constraint integrity.

### 2b. SCD Type 2 Current Row Uniqueness

Active Type 2 dimensions must have exactly one current row per natural key.

```sql
SELECT [_Source{EntityID}], COUNT(*) AS CurrentRows
FROM [Dimension].[{EntityName}]
WHERE IsCurrent = 1
GROUP BY [_Source{EntityID}]
HAVING COUNT(*) > 1;
```

Expected result: 0 rows. Multiple current rows for a natural key indicate data corruption.

### 2c. Calendar Completeness

The calendar must cover the full range of date keys used in fact tables, and must be contiguous.

```sql
SELECT 
    MIN([Date Key]) AS CalendarMin,
    MAX([Date Key]) AS CalendarMax,
    COUNT(*) AS CalendarRows,
    DATEDIFF(DAY, MIN([Date Key]), MAX([Date Key])) + 1 AS ExpectedRows
FROM [Dimension].[Calendar]
WHERE [Date Key] > '1753-01-01' AND [Date Key] < '9999-12-31';  -- exclude sentinels
-- CalendarRows must = ExpectedRows (no gaps)
```

```sql
SELECT
    MIN(f.[Order Date Key]) AS FactMinDateKey,
    MAX(f.[Order Date Key]) AS FactMaxDateKey
FROM [Fact].[{FactName}] f
WHERE f.[Order Date Key] > '1753-01-01';  -- exclude sentinel rows from range check
```

Verify that `CalendarMin ≤ FactMinDateKey` and `CalendarMax ≥ FactMaxDateKey`.

## 3. Fact Table Validation

Run these checks after executing `Fact.Load{Entity}`.

### 3a. Orphan Fact Rows

Run this pattern for each dimension foreign key on the fact table.

```sql
SELECT COUNT(*) AS OrphanRows
FROM [Fact].[{FactName}] f
LEFT JOIN [Dimension].[{DimName}] d
    ON f.[{DimName}Key] = d.[{DimName}Key]
WHERE d.[{DimName}Key] IS NULL;
```

Expected result: 0 rows. Any orphan rows are a CRITICAL finding.

### 3b. Invalid Date Keys

Date FK columns in fact tables use `DATE` type. The org sentinel for unknown/missing dates is `'1753-01-01'` — this is **valid** and must not be flagged as an orphan. Only true NULLs or dates not in `Dimension.Calendar` (excluding the sentinel itself) are invalid.

```sql
-- Check for NULLs (should be 0 — sentinel '1753-01-01' is used instead of NULL)
SELECT COUNT(*) AS NullDateKeys
FROM [Fact].[{FactName}]
WHERE [{Role}Date Key] IS NULL;

-- Check for orphan date keys (dates not in Calendar, excluding sentinel which is valid)
SELECT COUNT(*) AS InvalidDateKeys
FROM [Fact].[{FactName}] f
LEFT JOIN [Dimension].[Calendar] c
    ON f.[{Role}Date Key] = c.[Date Key]
WHERE c.[Date Key] IS NULL;
```

Expected results: both queries return 0. A non-zero result on the second query indicates rows whose date is not in the Calendar range — typically future dates beyond `MAX([Date Key])` or dates from source data that pre-date Calendar's lower bound.

### 3c. Row Count vs Prior Load

Compare current load row count to the previous successful lineage entry. Unexpected drops can indicate truncation, a failed source extract, or an incomplete load window.

```sql
SELECT 
    l1.EndTime,
    l1.RowsLoaded AS ThisLoad,
    l2.RowsLoaded AS PriorLoad,
    l1.RowsLoaded - l2.RowsLoaded AS Delta
FROM [Internal].[Lineage] l1
JOIN [Internal].[Lineage] l2
    ON l1.PackageName = l2.PackageName
    AND l2.LineageKey = (
        SELECT MAX(LineageKey)
        FROM [Internal].[Lineage]
        WHERE PackageName = l1.PackageName
          AND LineageKey < l1.LineageKey
          AND Status = 'Success'
    )
WHERE l1.PackageName = N'{PackageName}'
ORDER BY l1.LineageKey DESC;
```

### 3d. Measure Sanity Checks

Use domain rules to decide whether negative values are valid for each additive measure.

```sql
SELECT COUNT(*) AS NegativeRows
FROM [Fact].[{FactName}]
WHERE [{MeasureColumn}] < 0;
```

```sql
SELECT COUNT(*) AS NullMeasureRows
FROM [Fact].[{FactName}]
WHERE [{MeasureColumn}] IS NULL;
```

Expected result: 0 rows unless the measure definition explicitly allows negatives or NULLs.

## 4. Referential Integrity Checks

Use this metadata query to list fact foreign key coverage. Generate and run orphan-count queries for each returned row.

```sql
SELECT 
    OBJECT_SCHEMA_NAME(fk.parent_object_id) AS FactSchema,
    OBJECT_NAME(fk.parent_object_id) AS FactTable,
    pc.name AS FKColumn,
    OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS DimSchema,
    OBJECT_NAME(fk.referenced_object_id) AS DimTable,
    rc.name AS ReferencedColumn,
    'SELECT COUNT(*) AS OrphanCount FROM ['
        + OBJECT_SCHEMA_NAME(fk.parent_object_id) + '].['
        + OBJECT_NAME(fk.parent_object_id) + '] f LEFT JOIN ['
        + OBJECT_SCHEMA_NAME(fk.referenced_object_id) + '].['
        + OBJECT_NAME(fk.referenced_object_id) + '] d ON f.['
        + pc.name + '] = d.[' + rc.name + '] WHERE d.['
        + rc.name + '] IS NULL;' AS OrphanCheckSql
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc
    ON fk.object_id = fkc.constraint_object_id
JOIN sys.columns pc
    ON fkc.parent_object_id = pc.object_id
   AND fkc.parent_column_id = pc.column_id
JOIN sys.columns rc
    ON fkc.referenced_object_id = rc.object_id
   AND fkc.referenced_column_id = rc.column_id
WHERE OBJECT_SCHEMA_NAME(fk.parent_object_id) = 'Fact'
ORDER BY OBJECT_NAME(fk.parent_object_id), pc.name;
```

Expected result: every fact foreign key has a generated orphan check, and each executed orphan check returns 0.

## 5. Deployment Smoke Tests

Run these checks after the release completes.

### 5a. DW Connectivity

Run in a post-deploy validation step.

```sql
SELECT 
    SERVERPROPERTY('ServerName') AS Server,
    DB_NAME() AS DatabaseName,
    GETDATE() AS CheckTime;
```

Expected result: returns 1 row without error.

### 5b. SSAS Connectivity

Run against the semantic endpoint.

```sql
-- State = 1 means Ready. Query partitions (which hold state) joined to tables.
SELECT
    t.[Name]  AS TableName,
    p.[Name]  AS PartitionName,
    p.[State] AS PartitionState   -- 1 = Ready, 2 = NoData, 3 = CalculationNeeded, 4 = SemanticError
FROM $SYSTEM.TMSCHEMA_PARTITIONS p
JOIN $SYSTEM.TMSCHEMA_TABLES     t ON p.[TableID] = t.[ID]
WHERE t.[IsHidden] = FALSE
ORDER BY t.[Name], p.[Name];
```

Expected result: all rows show `PartitionState = 1` (Ready). Any other value means the partition needs processing.

### 5c. Last Successful ELT Run

```sql
SELECT TOP 1
    LineageKey,
    PackageName,
    StartTime,
    EndTime,
    RowsLoaded,
    Status,
    ErrorMessage
FROM [Internal].[Lineage]
ORDER BY LineageKey DESC;
```

Expected result: `Status = 'Success'` and `EndTime` is within the expected operational window.

### 5d. Dimension and Fact Row Counts

Compare current row counts to a baseline captured from a prior successful run.

```sql
SELECT 
    t.TABLE_SCHEMA + '.' + t.TABLE_NAME AS TableName,
    SUM(p.[rows]) AS EstimatedRows
FROM INFORMATION_SCHEMA.TABLES t
JOIN sys.objects o
    ON o.object_id = OBJECT_ID(QUOTENAME(t.TABLE_SCHEMA) + '.' + QUOTENAME(t.TABLE_NAME))
JOIN sys.partitions p
    ON p.object_id = o.object_id
   AND p.index_id IN (0, 1)
WHERE t.TABLE_SCHEMA IN ('Dimension', 'Fact')
  AND t.TABLE_TYPE = 'BASE TABLE'
GROUP BY t.TABLE_SCHEMA, t.TABLE_NAME
ORDER BY t.TABLE_SCHEMA, t.TABLE_NAME;
```

Expected result: row counts are within expected variance for the environment and load window.

## 6. Validation Checklist for Mode A Review

Use this severity-coded checklist when reviewing a DW schema for validation readiness.

| Check | Severity if absent | Query to run |
|---|---:|---|
| Unknown member row in every dimension | 🔴 CRITICAL | Section 2a |
| No duplicate natural keys in staging | 🔴 CRITICAL | Section 1b |
| No orphan fact rows | 🔴 CRITICAL | Section 3a |
| Calendar covers full fact date range | 🟠 HIGH | Section 2c |
| LineageKey assigned on all staging rows | 🟠 HIGH | Section 1d |
| No NULL natural keys in staging | 🟠 HIGH | Section 1c |
| No NULL additive measures in facts | 🟡 MEDIUM | Section 3d |
| Last ELT run completed successfully | 🟠 HIGH | Section 5c |
| All SSAS tables in ready state | 🟠 HIGH | Section 5b |

## 7. Usage Notes for Generated Recommendations

- Replace placeholders such as `{EntityName}`, `{EntityID}`, `{FactName}`, `{DimName}`, `{MeasureColumn}`, and `{PackageName}` before execution.
- Run staging checks before dimension and fact load procedures.
- Run dimension checks before dependent fact checks.
- Treat CRITICAL findings as release blockers unless there is an approved exception.
- Preserve environment-specific thresholds for row count deltas and measure variance.
