<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# DW Physical Design Reference

Physical design guidance for SQL Server Data Warehouses in the context of dimensional
modelling (Kimball). Covers indexing, statistics, staging design, and partitioning.

**Environment context:**
- SQL Server instance is shared between DW and OLTP databases (separate databases)
- Index maintenance is DBA-managed (do not generate maintenance scripts)
- Auto-update statistics is on across all databases
- Fact tables range from hundreds of thousands to low millions of rows
- Dimension tables are small (< 1M rows)

---

## 1. Index Strategy by Table Type

### 1.1 Fact Tables

#### Default recommendation (rowstore — all fact tables)

Fact tables are loaded nightly and read by SSAS during processing. The primary access
pattern is a full or range scan on the date key plus FK joins to dimensions.

```sql
-- Clustered index on DateKey (most selective range scan for processing and reports)
CREATE CLUSTERED INDEX [CIX_Fact_Sales_DateKey]
    ON [Fact].[Sales] ([Date Key]);

-- Non-clustered indexes on remaining foreign keys (for SSAS relationship joins)
CREATE NONCLUSTERED INDEX [NIX_Fact_Sales_ProductKey]
    ON [Fact].[Sales] ([Product Key]);

CREATE NONCLUSTERED INDEX [NIX_Fact_Sales_CustomerKey]
    ON [Fact].[Sales] ([Customer Key]);
```

**Naming convention:** `CIX_{Schema}_{Table}_{Column}` / `NIX_{Schema}_{Table}_{Column}`

#### When to consider Columnstore (CCI)

Columnstore indexes are batch-mode optimized for analytical scans and provide 5–10×
compression. They become advantageous when a fact table exceeds ~1 million rows **and**
SSAS processing time or ad-hoc query performance becomes a concern.

```sql
-- Clustered Columnstore Index (replaces CIX — use only when table > 1M rows)
CREATE CLUSTERED COLUMNSTORE INDEX [CCI_Fact_Sales]
    ON [Fact].[Sales];

-- Re-add non-clustered B-tree indexes on FK columns for SSAS join performance
-- (CCI does not replace NCI on low-cardinality join columns)
CREATE NONCLUSTERED INDEX [NIX_Fact_Sales_DateKey]
    ON [Fact].[Sales] ([Date Key]);

CREATE NONCLUSTERED INDEX [NIX_Fact_Sales_ProductKey]
    ON [Fact].[Sales] ([Product Key]);
```

> **Decision rule:** Start with rowstore (CIX on DateKey + NCI on FKs). Profile
> SSAS processing time and report query duration. Migrate to CCI when the table
> regularly exceeds 1M rows or processing time becomes a bottleneck.

#### Incremental loads — avoid index fragmentation

Nightly `MERGE` or `INSERT` loads into a rowstore clustered index cause fragmentation.
Notify the DBAs so their maintenance scripts include this table. Alternatively, set the
clustered index FILLFACTOR to 80% to defer fragmentation:

```sql
CREATE CLUSTERED INDEX [CIX_Fact_Sales_DateKey]
    ON [Fact].[Sales] ([Date Key])
    WITH (FILLFACTOR = 80);
```

---

### 1.2 Dimension Tables

Dimension tables are small (< 1M rows). The primary access patterns are:
- Point lookups by surrogate key (SSAS relationship joins)
- MERGE loads matching on natural key(s)
- SCD Type 2 lookups (current row flag, effective date range)

```sql
-- Clustered index on surrogate key (integer — minimal storage, optimal for FK joins)
CREATE CLUSTERED INDEX [CIX_Dimension_Customer_CustomerKey]
    ON [Dimension].[Customer] ([Customer Key]);

-- Non-clustered on natural key (used in MERGE and change-detection lookups)
CREATE NONCLUSTERED INDEX [NIX_Dimension_Customer_NaturalKey]
    ON [Dimension].[Customer] ([Customer Number]);

-- SCD Type 2: NCI on current-row flag + natural key (filtered index — efficient)
CREATE NONCLUSTERED INDEX [NIX_Dimension_Customer_Current]
    ON [Dimension].[Customer] ([Customer Number])
    WHERE [Is Current Row] = 1;
```

> **Rule of thumb:** One CIX (surrogate key) + one NCI (natural key) is sufficient for
> most dimensions. Add a filtered NCI on `[Is Current Row] = 1` for SCD Type 2 tables
> if the load SP runs slowly on the current-row lookup.

---

### 1.3 Staging Tables

Staging tables are **heaps** — they are truncated and fully reloaded on each ELT run.
A clustered index on a heap adds write overhead for no read benefit during load.

However, the **transform/load SPs** (`Dimension.Load*`, `Fact.Load*`) perform `MERGE`
operations that match against staging by natural key. Add a non-clustered index on the
natural key column(s) after the staging load completes.

**Option A — Index added by the staging load SP (preferred pattern):**

```sql
-- At the end of Staging.LoadCustomer (after all rows are inserted):
IF EXISTS (SELECT 1 FROM sys.indexes
           WHERE object_id = OBJECT_ID('Staging.Customer')
             AND name = 'NIX_Staging_Customer_NaturalKey')
    DROP INDEX [NIX_Staging_Customer_NaturalKey] ON [Staging].[Customer];

CREATE NONCLUSTERED INDEX [NIX_Staging_Customer_NaturalKey]
    ON [Staging].[Customer] ([Customer Number]);
```

**Option B — Staging table has a permanent NCI (acceptable for stable schemas):**

```sql
-- Defined on the table — survives TRUNCATE (indexes survive TRUNCATE TABLE)
CREATE NONCLUSTERED INDEX [NIX_Staging_Customer_NaturalKey]
    ON [Staging].[Customer] ([Customer Number]);
```

> **Note:** `TRUNCATE TABLE` preserves indexes; `DROP TABLE / CREATE TABLE` does not.
> If the staging table is rebuilt each run, use Option A.

---

### 1.4 Internal / Control Tables

`Internal.Lineage`, `Internal.IncrementalLoads`, `Internal.ProcedureError`, etc. are
low-volume operational tables. Standard clustered index on the identity PK is sufficient.
No additional tuning needed.

---

## 2. Statistics

Auto-update statistics is enabled on all DW databases and is managed by the DBA team.
Do **not** generate manual `UPDATE STATISTICS` scripts as standalone maintenance objects.

**Exception — post-load statistics hint for large fact tables:**

After a nightly full load into a large fact table (>500K rows inserted), auto-update
statistics may not trigger immediately (threshold: 20% of row count modified). Include
a targeted `UPDATE STATISTICS` call at the **end of the fact load SP** to ensure query
plans are current before SSAS processing begins:

```sql
-- At the end of Fact.LoadSales (after MERGE completes):
UPDATE STATISTICS [Fact].[Sales] WITH FULLSCAN;
```

> Coordinate with DBAs before adding this — confirm it does not conflict with their
> scheduled maintenance window. If their maintenance job runs before SSAS processing,
> the SP-level call is redundant.

---

## 3. Partitioning

Partitioning is not currently in use. It is acceptable to introduce it on a per-table
basis provided:
1. The partitioning scheme is fully scripted (no manual steps)
2. It does not require recurring DBA involvement after initial setup
3. Benefit must justify the added schema complexity

### 3.1 When partitioning is worth it

| Scenario | Recommendation |
|---|---|
| Fact table > 10M rows and growing; nightly load touches only the current month | Partition by `Date Key` (YYYYMM) — enables partition switching for incremental load |
| Full table `ALTER INDEX REBUILD` is affecting DW window | Partition-aligned rebuild targets only modified partitions |
| SSAS partition-by-month processing is desired | DW partition boundary must align with SSAS partition boundary |

> At current scale (hundreds of thousands to low millions), partitioning provides
> **marginal benefit**. Revisit when a fact table exceeds 5–10M rows.

### 3.2 Partition switching pattern (for future use)

The partition switching pattern allows zero-lock incremental loads into large fact tables.
The new period's rows are loaded into a staging table with the same schema, then switched
into the live partition with a metadata-only operation.

```sql
-- Step 1: Create partition function and scheme (one-time, done by DBA or pipeline)
CREATE PARTITION FUNCTION [PF_Fact_ByYear] (DATE)
AS RANGE RIGHT FOR VALUES ('2020-01-01', '2021-01-01', '2022-01-01', '2023-01-01', '2024-01-01');

CREATE PARTITION SCHEME [PS_Fact_ByYear]
AS PARTITION [PF_Fact_ByYear] ALL TO ([PRIMARY]);

-- Step 2: Fact table uses the partition scheme on [Date Key] (DATE type, matching Calendar FK)
CREATE TABLE [Fact].[Sales] (
    [Date Key]     DATE NOT NULL,
    [Product Key]  INT  NOT NULL,
    -- ... remaining columns
) ON [PS_Fact_ByYear] ([Date Key]);

-- Step 3: Staging table for the incoming partition (must match schema exactly)
CREATE TABLE [Staging].[Sales_Incoming] (
    [Date Key]     DATE NOT NULL,
    [Product Key]  INT  NOT NULL,
    -- ... remaining columns
) ON [PRIMARY];

-- Step 4: Nightly load SP — load into staging, then switch
TRUNCATE TABLE [Staging].[Sales_Incoming];

INSERT INTO [Staging].[Sales_Incoming]
SELECT ... FROM [Staging].[Sales]; -- transform result

-- Switch the staging table into partition N of the live table
ALTER TABLE [Staging].[Sales_Incoming]
SWITCH TO [Fact].[Sales] PARTITION $PARTITION.[PF_Fact_ByYear] ('2024-01-01');
```

> **Pre-requisite:** Both tables must have matching indexes, CHECK constraints on the
> partition column, and be on the same filegroup. Fully script this as a one-time DACPAC
> migration; the nightly SWITCH is pipeline-executable with no manual steps.

---

## 4. Shared Instance Considerations

The DW and OLTP databases share the same SQL Server instance. This affects:

| Risk | Mitigation |
|---|---|
| OLTP peak hours overlap with ELT window | Schedule ELT jobs outside OLTP peak (confirm with DBAs) |
| CCI batch-mode queries consume CPU competing with OLTP | Monitor via `sys.dm_exec_query_stats`; consider Resource Governor |
| Index REBUILD locks affect read availability | REBUILD with `ONLINE = ON` (requires Enterprise edition); or defer to DBA maintenance window |
| Statistics contention during auto-update | Accept auto-update; add manual call only in load SP for large facts |

---

## 5. Physical Design Checklist

Use this checklist when reviewing or generating DW DDL:

### Fact tables
- [ ] CIX on DateKey (rowstore default) or CCI (if > 1M rows and performance justifies)
- [ ] NCI on each FK column not included in the CIX
- [ ] FILLFACTOR 80% on CIX if nightly incremental loads cause fragmentation
- [ ] `UPDATE STATISTICS … WITH FULLSCAN` at end of load SP for tables > 500K rows loaded per night
- [ ] Partitioning documented as future option if table is growing toward 5–10M rows

### Dimension tables
- [ ] CIX on surrogate key (`{EntityName}Key`)
- [ ] NCI on natural key (used in MERGE)
- [ ] Filtered NCI on `[Is Current Row] = 1` if SCD Type 2 load is slow

### Staging tables
- [ ] Heap (no CIX) — tables are truncated/reloaded each run
- [ ] NCI on natural key added at end of staging load SP (if MERGE performance requires it)
- [ ] No FK constraints — staging is pre-validation

### General
- [ ] Index names follow `CIX_{Schema}_{Table}_{Column}` / `NIX_{Schema}_{Table}_{Column}` convention
- [ ] No redundant indexes (duplicate leading key columns)
- [ ] Shared instance: ELT window does not overlap OLTP peak hours
- [ ] All DDL changes are in SSDT project and deployed via DACPAC pipeline

---

## 6. Anti-Patterns to Flag

| Anti-Pattern | Impact | Fix |
|---|---|---|
| Fact table with no index on DateKey | Full scan on every SSAS process; slow report queries | Add CIX on DateKey |
| Dimension with no NCI on natural key | MERGE in load SP does table scan for change detection | Add NCI on natural key |
| Staging table with clustered index | Write overhead with no read benefit (table is truncated each time) | Drop CIX; keep as heap with post-load NCI |
| CCI on a < 100K row table | Delta store overhead; no compression gain | Use rowstore |
| Index FILLFACTOR 100% on append-only fact | Immediate page split fragmentation on every load | Set FILLFACTOR 80% |
| Index on every column in a fact table | Excessive storage; slows MERGE and INSERT | Limit to DateKey CIX + FK NCIs |
| Partitioning added without CHECK constraint | Partition elimination does not work — SQL Server cannot prove partition boundaries | Add `CHECK ([Date Key] BETWEEN … AND …)` on staging table before SWITCH |
