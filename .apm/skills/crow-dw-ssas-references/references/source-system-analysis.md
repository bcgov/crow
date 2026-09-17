<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# Source System Analysis

> **Authority:** Kimball (*The Data Warehouse Toolkit*, 3rd ed.) — Chapter 3 (Selecting the Business Process) and Chapter 19 (ETL Subsystems) define the source analysis discipline. SQLBI does not prescribe source discovery procedures; this reference covers pre-DW-design analysis only.

## Purpose

Provides a standardised T-SQL discovery query library for analysing source databases **before** DW design begins. Used by the `dw-report-designer` interview protocol (Phase 2) and **Mode P: Source System Analysis** to produce a classified entity map that feeds grain definition (Phase 3) and dimension design (Phase 5).

---

## Discovery Queries

### Q1 — Table Inventory with Row Counts

Lists all user tables with approximate row counts, column counts, and whether an identity column is present. Run this first to understand the scope of the source database.

```sql
SELECT
    t.TABLE_SCHEMA,
    t.TABLE_NAME,
    ISNULL(p.total_rows, 0)                              AS [Approx Row Count],
    COUNT(c.COLUMN_NAME)                                 AS [Column Count],
    MAX(CASE WHEN sc.is_identity = 1 THEN 1 ELSE 0 END) AS [Has Identity Column]
FROM INFORMATION_SCHEMA.TABLES t
JOIN INFORMATION_SCHEMA.COLUMNS c
    ON  c.TABLE_SCHEMA = t.TABLE_SCHEMA
    AND c.TABLE_NAME   = t.TABLE_NAME
-- Join sys.tables to get a stable object_id for partitions and identity lookup
JOIN sys.tables st
    ON  st.schema_id = SCHEMA_ID(t.TABLE_SCHEMA)
    AND st.name      = t.TABLE_NAME
-- Aggregate partitions first to avoid row-count inflation on partitioned tables
LEFT JOIN (
    SELECT object_id, SUM(rows) AS total_rows
    FROM   sys.partitions
    WHERE  index_id IN (0, 1)
    GROUP BY object_id
) p  ON p.object_id = st.object_id
-- At most one identity column per table; LEFT JOIN is safe
LEFT JOIN sys.columns sc
    ON  sc.object_id  = st.object_id
    AND sc.is_identity = 1
WHERE t.TABLE_TYPE = 'BASE TABLE'
GROUP BY t.TABLE_SCHEMA, t.TABLE_NAME, p.total_rows
ORDER BY ISNULL(p.total_rows, 0) DESC;
```

---

### Q2 — Date Column and Status/Type Column Detection

Identifies all date/datetime columns (Calendar FK candidates) and columns whose names suggest status, type, flag, or code (junk dimension candidates). Run across all tables.

> **Note:** Pattern matching on column names (`%Code%`, `%Type%`, etc.) will produce false positives (e.g. `PostalCode`, `EncodedPayload`). Treat Q2 output as a candidate list requiring human triage — do not feed Q7 without reviewing results first.

```sql
SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    CASE
        WHEN DATA_TYPE IN (
            'date', 'datetime', 'datetime2',
            'smalldatetime', 'datetimeoffset')
        THEN 'Date column'
        ELSE 'Status/Type/Code column'
    END AS [Column Role]
FROM INFORMATION_SCHEMA.COLUMNS
WHERE DATA_TYPE IN (
        'date', 'datetime', 'datetime2',
        'smalldatetime', 'datetimeoffset')
   OR COLUMN_NAME LIKE '%Status%'
   OR COLUMN_NAME LIKE '%Type%'
   OR COLUMN_NAME LIKE '%Flag%'
   OR COLUMN_NAME LIKE '%Code%'
   OR COLUMN_NAME LIKE '%Indicator%'
   OR COLUMN_NAME LIKE '%Priority%'
ORDER BY TABLE_SCHEMA, TABLE_NAME, [Column Role], COLUMN_NAME;
```

---

### Q3 — Primary Key Map

Lists every primary key column with its data type. Single-column integer PKs in low-row-count tables are natural key candidates for dimension tables. Composite PKs suggest bridge tables or transaction-line-level fact grains.

> **GUID PKs:** `uniqueidentifier` PKs are valid natural/business keys but should not be used as DW surrogate keys — flag them as source alternate keys and generate a standard `INT IDENTITY` surrogate in the DW.

```sql
SELECT
    tc.TABLE_SCHEMA,
    tc.TABLE_NAME,
    kcu.COLUMN_NAME,
    kcu.ORDINAL_POSITION,
    c.DATA_TYPE,
    c.IS_NULLABLE
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
    ON  tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
    AND tc.TABLE_SCHEMA    = kcu.TABLE_SCHEMA
JOIN INFORMATION_SCHEMA.COLUMNS c
    ON  c.TABLE_NAME   = kcu.TABLE_NAME
    AND c.COLUMN_NAME  = kcu.COLUMN_NAME
    AND c.TABLE_SCHEMA = kcu.TABLE_SCHEMA
WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
ORDER BY tc.TABLE_SCHEMA, tc.TABLE_NAME, kcu.ORDINAL_POSITION;
```

---

### Q4 — Foreign Key Relationship Map

Maps all FK relationships between tables. **If this returns zero rows**, the database enforces referential integrity at the application layer — see the *No FK Constraints* section below.

```sql
SELECT
    fk.name                                     AS [FK Constraint],
    OBJECT_SCHEMA_NAME(fk.parent_object_id)     AS [From Schema],
    OBJECT_NAME(fk.parent_object_id)            AS [From Table],
    cp.name                                     AS [From Column],
    OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS [To Schema],
    OBJECT_NAME(fk.referenced_object_id)        AS [To Table],
    cr.name                                     AS [To Column]
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc
    ON fk.object_id = fkc.constraint_object_id
JOIN sys.columns cp
    ON  fkc.parent_column_id    = cp.column_id
    AND fkc.parent_object_id    = cp.object_id
JOIN sys.columns cr
    ON  fkc.referenced_column_id    = cr.column_id
    AND fkc.referenced_object_id    = cr.object_id
ORDER BY [From Schema], [From Table], [To Table];
```

---

### Q5 — Inbound / Outbound FK Count per Table

Summarises hub-vs-spoke structure. Tables with many **inbound** FKs (referenced by others) are dimension candidates. Tables with many **outbound** FKs (referencing others) are fact candidates.

```sql
SELECT
    SCHEMA_NAME(t.schema_id)     AS [Schema],
    t.name                       AS [Table],
    (SELECT COUNT(*)
     FROM sys.foreign_keys fk
     WHERE fk.parent_object_id = t.object_id)     AS [Outbound FKs],
    (SELECT COUNT(*)
     FROM sys.foreign_keys fk
     WHERE fk.referenced_object_id = t.object_id) AS [Inbound FKs],
    ISNULL(p.total_rows, 0)      AS [Approx Rows]
FROM sys.tables t
LEFT JOIN (
    SELECT object_id, SUM(rows) AS total_rows
    FROM   sys.partitions
    WHERE  index_id IN (0, 1)
    GROUP BY object_id
) p ON p.object_id = t.object_id
ORDER BY [Inbound FKs] DESC, [Outbound FKs] DESC;
```

---

### Q6 — NULL Rate Check on Key Columns (run per candidate fact table)

Run against each identified fact candidate to detect data quality issues in FK and key columns. High NULL rates on FK columns require sentinel value handling in ELT (`ISNULL(..., -1)` for integer dims; `ISNULL(..., '1753-01-01')` for date dims).

> **Performance:** For tables with more than ~10 million rows, profile only FK-like columns and date columns (identified from Q2 and Q4) rather than all columns.

```sql
-- Set @TableSchema and @TableName to the candidate fact table before running.
DECLARE @TableSchema NVARCHAR(128) = 'dbo';
DECLARE @TableName   NVARCHAR(128) = 'ReplaceWithActualTableName';
DECLARE @SQL         NVARCHAR(MAX) = N'';
DECLARE @Sep         NVARCHAR(30)  = N'';   -- separator accumulates after first row

SELECT
    @SQL += @Sep
         + N'SELECT ' + QUOTENAME(COLUMN_NAME, '''') + N' AS [Column],'
         + N' COUNT(*) AS [Total Rows],'
         + N' SUM(CASE WHEN ' + QUOTENAME(COLUMN_NAME) + N' IS NULL THEN 1 ELSE 0 END) AS [NULL Count],'
         + N' CAST(SUM(CASE WHEN ' + QUOTENAME(COLUMN_NAME) + N' IS NULL THEN 1 ELSE 0 END)'
         + N'      * 100.0 / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS [NULL %]'
         + N' FROM ' + QUOTENAME(@TableSchema) + N'.' + QUOTENAME(@TableName),
    @Sep = CHAR(10) + N'UNION ALL' + CHAR(10)
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = @TableSchema AND TABLE_NAME = @TableName
ORDER BY ORDINAL_POSITION;

IF LEN(ISNULL(@SQL, N'')) > 0
    EXEC sp_executesql @SQL;
```

---

### Q7 — Cardinality Profiling for Status/Type Columns (junk dimension candidates)

For each column flagged by Q2 as Status/Type, check the number of distinct values. Fewer than 20 distinct values → junk dimension candidate. Run once per column.

```sql
-- Set @TableSchema, @TableName, @ColumnName before running.
DECLARE @TableSchema NVARCHAR(128) = 'dbo';
DECLARE @TableName   NVARCHAR(128) = 'ReplaceWithActualTableName';
DECLARE @ColumnName  NVARCHAR(128) = 'ReplaceWithActualColumnName';
DECLARE @SQL         NVARCHAR(MAX);

SET @SQL = N'SELECT '
    + QUOTENAME(@ColumnName)
    + N' AS [Value], COUNT(*) AS [Row Count]'
    + N' FROM '    + QUOTENAME(@TableSchema) + N'.' + QUOTENAME(@TableName)
    + N' GROUP BY ' + QUOTENAME(@ColumnName)
    + N' ORDER BY [Row Count] DESC;';

EXEC sp_executesql @SQL;
```

---

### Q8 — Duplicate PK Check (run per candidate dimension table)

Before trusting a natural key for SCD design, verify it is actually unique. If duplicates exist, the source has data quality issues — the DW must either apply deduplication logic in Staging or escalate to the development team.

```sql
-- Set @TableSchema, @TableName, @PKColumn before running.
-- For composite PKs, add additional column names separated by commas.
DECLARE @TableSchema NVARCHAR(128) = 'dbo';
DECLARE @TableName   NVARCHAR(128) = 'ReplaceWithActualTableName';
DECLARE @PKColumn    NVARCHAR(128) = 'ReplaceWithPKColumnName';
DECLARE @SQL         NVARCHAR(MAX);

SET @SQL = N'SELECT ' + QUOTENAME(@PKColumn)
    + N', COUNT(*) AS [Occurrences]'
    + N' FROM ' + QUOTENAME(@TableSchema) + N'.' + QUOTENAME(@TableName)
    + N' GROUP BY ' + QUOTENAME(@PKColumn)
    + N' HAVING COUNT(*) > 1'
    + N' ORDER BY [Occurrences] DESC;';

EXEC sp_executesql @SQL;
-- Zero rows returned = PK is unique (safe natural key)
-- Any rows returned = duplicates exist — flag as data quality issue
```

---

### Q9 — Date Range Profiling on Fact Candidates

For each fact candidate, profile the MIN/MAX/distinct-count of its date columns. This directly drives the Calendar dimension start date required by Mode H.

```sql
-- Set @TableSchema, @TableName, @DateColumn before running (once per date column per fact candidate).
DECLARE @TableSchema NVARCHAR(128) = 'dbo';
DECLARE @TableName   NVARCHAR(128) = 'ReplaceWithActualTableName';
DECLARE @DateColumn  NVARCHAR(128) = 'ReplaceWithDateColumnName';
DECLARE @SQL         NVARCHAR(MAX);

SET @SQL = N'SELECT '
    + QUOTENAME(@DateColumn, '''') + N' AS [Date Column],'
    + N' CAST(MIN(' + QUOTENAME(@DateColumn) + N') AS DATE)  AS [Earliest Date],'
    + N' CAST(MAX(' + QUOTENAME(@DateColumn) + N') AS DATE)  AS [Latest Date],'
    + N' COUNT(DISTINCT CAST(' + QUOTENAME(@DateColumn) + N' AS DATE)) AS [Distinct Dates],'
    + N' COUNT(*) AS [Total Rows],'
    + N' SUM(CASE WHEN ' + QUOTENAME(@DateColumn) + N' IS NULL THEN 1 ELSE 0 END) AS [NULL Count]'
    + N' FROM ' + QUOTENAME(@TableSchema) + N'.' + QUOTENAME(@TableName) + N';';

EXEC sp_executesql @SQL;
-- Use the earliest date to set Calendar start date (round back to a clean fiscal year start)
```

---

### Q10 — CDC / Change Tracking Detection

Detects whether CDC (Change Data Capture) or Change Tracking is enabled at the database or table level. This directly determines the incremental ELT strategy for Mode K and Mode M.

```sql
-- Step 1: Check database-level CDC and Change Tracking enablement
SELECT
    name                    AS [Database],
    is_cdc_enabled          AS [CDC Enabled],
    is_change_tracking_on   = CASE WHEN ctdb.database_id IS NOT NULL THEN 1 ELSE 0 END
FROM sys.databases db
LEFT JOIN sys.change_tracking_databases ctdb ON ctdb.database_id = db.database_id
WHERE db.database_id = DB_ID();

-- Step 2: List tables enrolled in CDC (if CDC is enabled)
IF EXISTS (SELECT 1 FROM sys.databases WHERE database_id = DB_ID() AND is_cdc_enabled = 1)
BEGIN
    SELECT
        OBJECT_SCHEMA_NAME(source_object_id) AS [Schema],
        OBJECT_NAME(source_object_id)        AS [Table],
        capture_instance,
        start_lsn
    FROM cdc.change_tables;
END

-- Step 3: List tables with Change Tracking enabled (if CT is enabled)
IF EXISTS (SELECT 1 FROM sys.change_tracking_databases WHERE database_id = DB_ID())
BEGIN
    SELECT
        SCHEMA_NAME(t.schema_id) AS [Schema],
        t.name                   AS [Table],
        ct.is_track_columns_updated_on AS [Track Column Changes]
    FROM sys.change_tracking_tables ct
    JOIN sys.tables t ON t.object_id = ct.object_id;
END
```

**Interpretation:**
- CDC or CT enabled on source tables → **incremental ELT** (Mode K merge pattern) is feasible
- Neither enabled → must use **full load + staging swap** or **watermark column** strategy
- Record findings in the entity map under a "Source Change Detection" section

---

## Classification Heuristics

After running Q1–Q5, classify each table using this decision tree. Apply in order — stop at the first match.

| Priority | Signal | Classification |
|---|---|---|
| 1 | Name contains: `Log`, `Audit`, `History`, `Archive`, `Temp`, `Backup` | **Ignore** |
| 2 | Name contains: `Config`, `Setting`, `Parameter`, `Lookup` with rows < 50 | **Ignore unless named by user** |
| 3 | Composite PK (≥ 2 PK columns) whose columns are all FKs to other tables | **Bridge table candidate** |
| 4 | Rows > 50,000 AND outbound FKs ≥ 2 AND ≥ 1 date column | **Fact candidate** |
| 5 | Rows > 50,000 AND ≥ 1 date column AND **Q4 returned zero FK constraints database-wide** | **Fact candidate (inferred)** — also check: column count ≥ 20, ≥ 3 numeric columns, or name contains `Order`, `Invoice`, `Payment`, `Claim`, `Transaction`, `Event` |
| 6 | Rows < 10,000 AND inbound FKs ≥ 1 AND mostly `VARCHAR`/`NVARCHAR` columns | **Dimension candidate** |
| 7 | Rows < 1,000 AND columns ≤ 5 AND has a code + description pattern | **Reference/lookup** → likely inline or junk dimension |
| 8a | Rows = 0 AND composite PK | **Fact candidate (structural, low confidence)** — include in map with note |
| 8b | Rows = 0 AND single-column PK AND mostly `VARCHAR`/`NVARCHAR` columns | **Dimension candidate (structural, low confidence)** — include in map with note |
| 9 | All others | **Unclassified** — present to user for manual classification |

> **Priority 5 clarification:** Priority 5 applies **only when Q4 returned zero FK constraints for the entire database**. If Q4 found FK constraints elsewhere in the database, use Priority 4 — a table that happens to have no FKs is not automatically an inferred fact candidate.

> **Zero-row tables:** Apply structural classification (Priority 8a/8b) based on PK shape and column types. Mark low confidence and include in the entity map for user confirmation.

---

## No FK Constraints Defined

Some OLTP systems enforce referential integrity at the application layer with no SQL FK constraints. When Q4 returns zero rows:

1. Add a visible warning in the entity map: **"⚠️ No FK constraints found. Relationships inferred from column naming patterns and row counts only. Confirm with the development team before proceeding."**
2. Apply implied FK detection: look for columns in high-row-count tables named `[EntityName]ID`, `[EntityName]Key`, or `[EntityName]Code` whose names match PK column names in lower-row-count tables.
3. Present **inferred relationships** in a separate section of the entity map, clearly labelled as inferred, not confirmed.
4. Ask the user: *"I can see columns like `CustomerID` in `WorkOrders` but no FK constraint links them to a `Customers` table. Can you confirm what `CustomerID` refers to, and whether there are other column relationships I should know about?"*

---

## Source Entity Map — Output Format

After running Q1–Q5 (and Q6/Q8 per fact candidate, Q7 per status column, Q9 per fact date column, Q10 once), produce the following structured output:

```
## Source Entity Map — [SourceServer].[SourceDatabase]

> Discovery run: [date]  
> ⚠️ No FK constraints defined — relationships are inferred.  ← include only if Q4 returned zero rows

### Fact Candidates

| Table | Schema | Approx Rows | Date Columns | Outbound FKs | Notes |
|---|---|---|---|---|---|
| WorkOrders | dbo | 2,100,000 | CreatedDate, CompletedDate, DueDate | 4 | CreatedDate likely maps to Calendar |

### Dimension Candidates

| Table | Schema | Approx Rows | Inbound FKs | Natural Key Column | SCD Potential |
|---|---|---|---|---|---|
| Customers | dbo | 4,200 | 3 | CustomerID (INT) | SCD Type 1 or 2 — confirm in Phase 5 |

### Reference / Lookup Tables

| Table | Schema | Rows | Notes |
|---|---|---|---|
| WorkOrderStatus | dbo | 6 | Code + Description — junk dimension candidate |

### Inferred Relationships (no FK constraints)

| From Table | From Column | To Table | To Column | Confidence |
|---|---|---|---|---|
| WorkOrders | CustomerID | Customers | CustomerID | High — column name match + row count ratio |

### Ignored Tables

| Table | Reason |
|---|---|
| WorkOrdersAudit | Name contains 'Audit' |

### Source Change Detection

| Mechanism | Enabled | Enrolled Tables |
|---|---|---|
| CDC | Yes / No | Orders, Customers |
| Change Tracking | No | — |

> If neither CDC nor CT is enabled, ELT strategy defaults to full-load + staging swap or watermark column — confirm with the source team.

### Data Quality Flags

| Table | Column | NULL % | Recommended ELT Action |
|---|---|---|---|
| WorkOrders | CustomerID | 3.2% | Add ISNULL(CustomerID, -1) in Staging.LoadWorkOrders |

### Grain Proposals

For each Fact candidate, one grain proposal:

**WorkOrders** → Proposed grain: *one row per work order* (`WorkOrderID` is the natural key).  
Confirm: does the report need line-item detail within a work order, or is one-row-per-order sufficient?
```

---

## CSV Source Discovery (automated)

For sources delivered as CSV files — either directly (flat file extracts) or as metadata/header exports from non-SQL systems (Salesforce, Oracle, PostgreSQL, etc.) — apply automated profiling instead of T-SQL queries. The output format (Source Entity Map) is identical to the SQL Server path so downstream phases consume it the same way.

### Inputs required from the user

1. **The CSV file(s)** — either the actual source data extract or a header-only / sample export (10–1000 rows is sufficient for profiling)
2. **One CSV per logical entity** — if the source is Salesforce, that means one CSV per object (Account.csv, Opportunity.csv, etc.). If the source is a single flat-file feed, that is one CSV.
3. **The delimiter and quoting convention** if non-standard (default assumed: comma-delimited, double-quote text qualifier, header row in row 1)
4. **Any known PK columns or FK relationships** that aren't obvious from column names — CSV has no constraint metadata

### Automated profiling

For each CSV file, derive the same information that Q1–Q9 produce for SQL Server:

| SQL Server query | CSV equivalent |
|---|---|
| Q1 Table inventory | List of CSV files + row count per file (line count − 1 header row) + column count (header row length) |
| Q2 Date / status column detection | Parse header names for `Date`, `Time`, `Status`, `Type`, `Code`, `Flag` patterns; sample-parse first 100 values per candidate column to confirm date parseability and value cardinality |
| Q3 Primary key map | Profile each column for uniqueness across the full file (or sample); flag single columns and 2–3 column combinations with 100% uniqueness as PK candidates |
| Q4 Foreign key relationship map | Name-pattern match: columns named `[Entity]ID`, `[Entity]Key`, `[Entity]Code` in one file matched against PK candidates in other files. Treat all CSV-derived relationships as **inferred** (CSV has no FK metadata). |
| Q5 Inbound/outbound FK count | Derived from Q4 inferred relationships |
| Q6 NULL rate check | Count empty strings + `NULL` literal per column; report percentage |
| Q7 Cardinality profiling | Distinct count + top 20 values per status/type column |
| Q8 Duplicate PK check | Group-by on PK candidate; report any group count > 1 |
| Q9 Date range profiling | MIN/MAX of parsed date values per date column on each Fact candidate |
| Q10 CDC / Change Tracking | Not applicable — CSV is a snapshot. Ask the user: is this a one-time load, an incremental drop (daily file with new rows only), or a full snapshot per delivery? This determines the ELT strategy. |

### Tools

Profile the CSV using one of these two preferred tools (this environment is Windows; Python is typically not installed):

1. **PowerShell** (always available, preferred for small-to-medium CSVs up to ~100k rows): `Import-Csv` for parsing, `Group-Object` for cardinality and PK uniqueness, `Measure-Object` for row count and NULL rate. Example:
   ```powershell
   $rows = Import-Csv .\Customers.csv
   $rows.Count                                        # row count
   ($rows | Get-Member -MemberType NoteProperty).Name # column list
   $rows | Group-Object CustomerID |
       Where-Object Count -gt 1                       # duplicate PK check
   $rows | Group-Object Status |
       Select-Object Name, Count                      # cardinality / Q7 equivalent
   ($rows | Where-Object { -not $_.Region }).Count /
       $rows.Count                                    # NULL rate on Region
   ```
2. **SQL Server bulk-load** (preferred for large CSVs > ~100k rows, or when joining across multiple CSVs is needed): bulk-load each CSV into a `Staging` table on an available SQL Server instance, then run the standard Q1–Q9 queries against the staged tables. Use `BULK INSERT` or `OPENROWSET(BULK ...)` — both work without SSIS for ad-hoc discovery.

> **Python / pandas is NOT a default option** in this environment — do not assume Python is installed. If a CSV is too large for PowerShell and no SQL Server instance is available for staging, ask the user before attempting any other tool.

Use the simpler tool (PowerShell) first; fall back to SQL Server bulk-load only when row volume or cross-file joins require it.

### Output

Produce the same `design/entity-map.md` structure as the SQL Server path. Add a header note:

> **Source type:** CSV — [file count] file(s), [delivery method: one-time / incremental / full snapshot]
> **Discovery confidence:** medium — automated profiling complete; all FK relationships are inferred from column names (CSV has no constraint metadata). User confirmation required before Phase 3.

All FK relationships derived from CSV go into the **Inferred Relationships** section, never the main relationship list — same rule as SQL Server with no FK constraints.

### When the user can't provide a CSV

Some non-SQL sources (legacy mainframes, proprietary APIs) cannot easily produce a header export. In that case, fall back to fully **manual discovery**:

1. Ask the user to describe each entity in plain language (table name, key fields, relationships).
2. Build `design/entity-map.md` manually from the description with confidence marked `low — no automated profiling`.
3. Note the connector requirement for the eventual SSIS data flow (e.g. Salesforce requires the KingswaySoft SSIS connector; mainframes typically need a custom extract job; REST APIs need a per-API script).

Mode N must not proceed past Mode P for manual-discovery sources until the user explicitly signs off the manually-built entity map.

---



## Feeding Phases 3, 4, and 5

After presenting the Source Entity Map:

- **Phase 3 (Grain)**: use Fact Candidates table to anchor the grain discussion. *"I can see `[Table]` has [N] rows and a natural PK of `[Column]`. Is 'one row per [plain-language description]' the right grain for this report?"*
- **Phase 4 (Measures)**: use numeric columns identified in Q6/Q9 profiling as additive/semi-additive/non-additive measure candidates. Flag amounts and quantities as additive, balances and ratios as semi-additive or non-additive — confirm with user before classifying.
- **Phase 5 (Dimensions)**: use Dimension Candidates table to prime the SCD and hierarchy questions. Pre-populate the SCD type question with the candidates found here rather than asking the user to list dimensions from scratch.
