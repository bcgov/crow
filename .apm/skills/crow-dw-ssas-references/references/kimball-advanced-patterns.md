<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# Kimball Advanced Implementation Patterns

> **Authority Note:** For SSAS Tabular semantic layer and DAX, **SQLBI (Marco Russo & Alberto Ferrari)** is the primary authority — use `sqlbi-dax-patterns.md`, `sqlbi-dax-patterns-advanced.md`, and `ssas-tabular-bp.md`. This file covers **physical SQL Server DW implementation details** that supplement the foundational Kimball modeling patterns in `kimball-patterns.md`. When Kimball guidance conflicts with SQLBI/Power BI best practices, SQLBI takes precedence for the semantic layer.

SQL Server–specific implementation patterns for dimensional data warehouses.
Supplements `kimball-patterns.md` (foundational modeling theory).
For org naming conventions, see `kimball-patterns.md`.

---

## Data Vault 2.0 Awareness

### Overview
Data Vault 2.0 (Dan Linstedt) is an alternative modeling methodology to Kimball. Many organizations run **hybrid** architectures where Data Vault is used in the Raw/Integration Vault layer and Kimball Star Schema is used in the Information Mart (presentation layer fed to SSAS).

### Key Constructs

| Construct | Role | Kimball Equivalent |
|---|---|---|
| **Hub** | Stores business keys only (no attributes) | Natural key in a Dimension |
| **Link** | Stores many-to-many relationships between hubs | Bridge table or Fact table |
| **Satellite** | Stores descriptive attributes + full history with load date | SCD Type 2 Dimension |

### Kimball vs. Data Vault

| Dimension | Kimball Star Schema | Data Vault 2.0 |
|---|---|---|
| Primary use case | Presentation / BI / SSAS feed | Raw integration, auditability, agility |
| History model | SCD Types 0–6 (design choice) | All history, always (satellites append-only) |
| Query complexity | Low (star joins) | High (hub+satellite joins before mart) |
| Loading pattern | SCD MERGE | Insert-only (no updates) |
| SSAS compatibility | Direct — star schema maps naturally | Requires Information Mart (star) as intermediate |
| ETL change impact | Re-engineering of dimensions | Add new satellite (non-breaking) |

### Hybrid Pattern for On-Premises SQL Server
```
Raw Sources → [Staging] → [Raw Vault (Hubs + Links + Satellites)]
                                       │
                          [Business Vault (computed satellites)]
                                       │
                          [Information Mart (Star Schema / Kimball)]
                                       │
                              [SSAS Tabular Model]
                                       │
                              [PBIRS Reports]
```

> **Recommendation:** If your organization already has a Data Vault, **do not** try to point SSAS Tabular directly at vault tables. Always build a Kimball-style Information Mart (star schema) as the semantic layer between the vault and SSAS. DAX and SSAS relationships are optimized for star schema, not vault topology.

---

## SQL Server–Specific DW Physical Design

### Columnstore Indexes on Fact Tables

Columnstore indexes (introduced SQL Server 2012, mature from 2016+) are the **primary performance optimization** for DW fact tables. They compress data by column and enable batch-mode execution.

```sql
-- Clustered Columnstore Index on a fact table (recommended for all large fact tables)
-- Drop any existing clustered index first, then:
CREATE CLUSTERED COLUMNSTORE INDEX CCI_SalesOrder
ON [Fact].[SalesOrder]
WITH (DATA_COMPRESSION = COLUMNSTORE_ARCHIVE,  -- for cold/historical partitions
      MAXDOP = 4);                             -- limit parallelism during rebuild

-- For the active/hot partition, use COLUMNSTORE (no ARCHIVE) for faster query:
CREATE CLUSTERED COLUMNSTORE INDEX CCI_SalesOrder
ON [Fact].[SalesOrder]
WITH (DATA_COMPRESSION = COLUMNSTORE, MAXDOP = 4);
```

**Columnstore guidelines for DW fact tables:**
- Use **Clustered Columnstore Index (CCI)** on all fact tables > 1M rows.
- CCI eliminates the need for most traditional non-clustered indexes on fact tables.
- Row groups are 1,048,576 rows each. Bulk-load in batches ≥ 102,400 rows to avoid "delta store" accumulation.
- Run `ALTER INDEX ... REORGANIZE` (not REBUILD) on CCIs during maintenance windows — REORGANIZE is online.
- Check delta store health with `sys.column_store_row_groups`.

```sql
-- Monitor CCI row group health
SELECT  i.name,
        rg.state_desc,
        rg.total_rows,
        rg.deleted_rows,
        rg.size_in_bytes / 1024.0 / 1024.0 AS SizeMB
FROM    sys.column_store_row_groups rg
JOIN    sys.indexes i ON i.object_id = rg.object_id AND i.index_id = rg.index_id
WHERE   i.type IN (5, 6)   -- 5=CCI, 6=NCCI
ORDER   BY rg.object_id, rg.row_group_id;
```

### Table Partitioning Strategy

Partition large fact tables and periodic snapshot tables by the most common filter column (usually `DateKey` or a date range column).

```sql
-- Step 1: Create partition function (monthly; DATE type matches Calendar PK)
CREATE PARTITION FUNCTION PF_Monthly (DATE)
AS RANGE RIGHT FOR VALUES (
    '2023-01-01', '2023-02-01', '2023-03-01', '2023-04-01', '2023-05-01', '2023-06-01',
    '2023-07-01', '2023-08-01', '2023-09-01', '2023-10-01', '2023-11-01', '2023-12-01',
    '2024-01-01'  -- add each new month before the month begins
);

-- Step 2: Create partition scheme
CREATE PARTITION SCHEME PS_Monthly
AS PARTITION PF_Monthly
ALL TO ([PRIMARY]);          -- route all to PRIMARY; adjust for filegroup strategy

-- Step 3: Create fact table on partition scheme
CREATE TABLE [Fact].[SalesOrder] (
    SalesOrderKey    BIGINT        NOT NULL,
    [Order Date Key] DATE          NOT NULL,
    CustomerKey      INT           NOT NULL,
    ProductKey       INT           NOT NULL,
    SalesAmount      DECIMAL(18,4) NOT NULL,
    Quantity         INT           NOT NULL,
    LineageKey       INT           NULL
) ON PS_Monthly ([Order Date Key]);

-- Step 4: Create CCI aligned to partition scheme
CREATE CLUSTERED COLUMNSTORE INDEX CCI_SalesOrder
ON [Fact].[SalesOrder]
ON PS_Monthly (OrderDateKey);
```

**Partition switching for ETL (zero-downtime load):**
```sql
-- Load new month data into a staging table, then switch in
CREATE TABLE [Staging].[FactSalesOrder_202401] (... same schema as [Fact].[SalesOrder] ...)
ON [PRIMARY];

-- Populate staging, then atomic switch
ALTER TABLE [Staging].[FactSalesOrder_202401]
    SWITCH TO [Fact].[SalesOrder] PARTITION
    $PARTITION.PF_Monthly(20240101);
```

### Filegroup Strategy

Distribute I/O by placing different DW layers on separate filegroups backed by different storage tiers.

```sql
-- Recommended filegroup layout for a DW database
ALTER DATABASE [DW_Production] ADD FILEGROUP [FG_Dimensions];
ALTER DATABASE [DW_Production] ADD FILEGROUP [FG_Facts_Hot];    -- current 2 years
ALTER DATABASE [DW_Production] ADD FILEGROUP [FG_Facts_Cold];   -- historical, read-only

ALTER DATABASE [DW_Production]
ADD FILE (NAME = 'DW_Dims',    FILENAME = '$(sql_data_root)\DW_Dims.ndf',    SIZE = 512MB, FILEGROWTH = 256MB)
TO FILEGROUP [FG_Dimensions];

ALTER DATABASE [DW_Production]
ADD FILE (NAME = 'DW_Hot',     FILENAME = '$(sql_data_root)\DW_Hot.ndf',     SIZE = 4096MB, FILEGROWTH = 1024MB)
TO FILEGROUP [FG_Facts_Hot];

ALTER DATABASE [DW_Production]
ADD FILE (NAME = 'DW_Cold',    FILENAME = '$(sql_archive_root)\DW_Cold.ndf', SIZE = 8192MB, FILEGROWTH = 2048MB)
TO FILEGROUP [FG_Facts_Cold];

-- Mark cold filegroup read-only after archiving old partitions
ALTER DATABASE [DW_Production] MODIFY FILEGROUP [FG_Facts_Cold] READ_ONLY;
```

### Statistics Management

Statistics are critical for the Query Optimizer on DW tables — especially with skewed date distributions.

```sql
-- Update statistics on all DW tables with full scan (not sampled)
-- Run after each nightly ETL load
USE [DW_Production];
EXEC sp_updatestats;          -- quick sampled update of stale statistics

-- Full scan update for fact tables where skew is suspected
UPDATE STATISTICS [Fact].[SalesOrder] WITH FULLSCAN;

-- Create additional statistics on frequently filtered non-key columns
CREATE STATISTICS STAT_SalesOrder_Channel
ON [Fact].[SalesOrder] (SalesChannelCode);

-- Auto-update statistics async (set at database level)
ALTER DATABASE [DW_Production] SET AUTO_UPDATE_STATISTICS ON;
ALTER DATABASE [DW_Production] SET AUTO_UPDATE_STATISTICS_ASYNC ON;
```

---

## Surrogate Key Generation Strategies

### 1. IDENTITY (Simplest — Recommended for Most Cases)

```sql
-- Standard IDENTITY surrogate key
CREATE TABLE [Dimension].[Customer] (
    CustomerKey       INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    _SourceCustomerID INT NOT NULL,
    ...
);
-- Note: Reserve negative values for special members
-- -1 = Unknown, -2 = Not Applicable, -3 = Error/Pending
-- Seed IDENTITY at 1; insert special members with SET IDENTITY_INSERT ON
SET IDENTITY_INSERT [Dimension].[Customer] ON;
INSERT [Dimension].[Customer] (CustomerKey, _SourceCustomerID, CustomerName, ...)
VALUES (-1, -1, 'Unknown', ...),
       (-2, -2, 'Not Applicable', ...);
SET IDENTITY_INSERT [Dimension].[Customer] OFF;
```

### 2. SEQUENCE Object (SQL Server 2012+)

Use SEQUENCE when surrogate keys must be coordinated across tables or generated outside INSERT statements (e.g., pre-assigned in ETL pipelines).

```sql
-- Create a shared sequence for a dimension family
CREATE SEQUENCE [Internal].[SEQ_CustomerKey]
    AS INT
    START WITH 1
    INCREMENT BY 1
    MINVALUE 1
    NO MAXVALUE
    NO CYCLE
    CACHE 1000;          -- cache 1000 values for performance

-- Use in ETL
DECLARE @NewKey INT = NEXT VALUE FOR [Internal].[SEQ_CustomerKey];

-- Use DEFAULT in table definition
CREATE TABLE [Dimension].[Customer] (
    CustomerKey INT NOT NULL DEFAULT (NEXT VALUE FOR [Internal].[SEQ_CustomerKey]) PRIMARY KEY,
    ...
);
```

### 3. MERGE-Based Key Lookup (ETL Pattern)

When loading fact tables, resolve natural keys to surrogate keys via lookup. Always include the Unknown member fallback.

```sql
-- Surrogate key lookup with Unknown member fallback
-- Used in ETL staging → fact load
INSERT INTO [Fact].[SalesOrder] (
    OrderDateKey, CustomerKey, ProductKey, SalesAmount, Quantity, LineageKey
)
SELECT
    ISNULL(cal.[Date Key], '1753-01-01')  AS OrderDateKey,
    ISNULL(dc.CustomerKey, -1)            AS CustomerKey,
    ISNULL(dp.ProductKey, -1)             AS ProductKey,
    s.SalesAmount,
    s.Quantity,
    @LineageKey                           AS LineageKey
FROM [Staging].[SalesOrder] s
LEFT JOIN [Dimension].[Calendar] cal
    ON cal.[Date Key] = CAST(s.OrderDate AS DATE)
LEFT JOIN [Dimension].[Customer] dc
    ON  dc._SourceCustomerID = s._SourceCustomerID
    AND dc.IsCurrent         = 1
LEFT JOIN [Dimension].[Product] dp
    ON  dp._SourceProductCode = s._SourceProductCode
    AND dp.IsCurrent          = 1;
```

---

## Late-Arriving Dimension Members

### Problem
A fact row arrives referencing a natural key (e.g., CustomerID = 9999) that does **not yet exist** in the dimension. A direct join returns NULL → if you use INNER JOIN, the fact is silently dropped.

### Solution: Unknown Member Pattern

1. **Pre-populate** the dimension with a surrogate key of `-1` representing "Unknown" or "Pending" for each dimension.
2. **ETL fact load**: Use `LEFT JOIN ... ISNULL(SK, -1)` (see surrogate key lookup above).
3. **Backfill job**: Run a periodic job to re-resolve fact rows with SK = -1 once the dimension member arrives.

```sql
-- Backfill previously unresolved fact rows
UPDATE f
SET    f.CustomerKey = dc.CustomerKey,
       f.LineageKey  = @LineageKey
FROM   [Fact].[SalesOrder] f
JOIN   [Staging].[SalesOrder_Unresolved] u ON u._SourceSalesOrderID = f._SourceSalesOrderID
JOIN   [Dimension].[Customer] dc
       ON  dc._SourceCustomerID = u._SourceCustomerID
       AND dc.IsCurrent         = 1
WHERE  f.CustomerKey = -1;
```

### Impact on SSAS Tabular — Default/Unknown Member
In SSAS Tabular with live PBIRS connections:
- Rows with SK = -1 will appear under the "Unknown" member in slicers.
- Ensure the `-1` row exists in the dimension with user-friendly label (e.g., "Unknown Customer") — otherwise SSAS will show a blank label, which confuses users.
- The SSAS relationship integrity will not fail as long as the `-1` SK is present in the dimension.
- Do **not** use `NULL` as FK in fact tables for SSAS — SSAS treats NULL FK differently (excluded from aggregation, not grouped under Unknown).

---

## Late-Arriving Facts

### Problem
A fact row arrives with a transaction date that falls in a **past period** during which the related dimension members had different attribute values (SCD Type 2 history). Simply resolving to `IsCurrent = 1` assigns the wrong dimension SK.

### Solution: Point-in-Time SCD Type 2 Resolution

```sql
-- Resolve dimension key as of the fact's transaction date
-- Not IsCurrent = 1, but the row that was current AT the transaction date
INSERT INTO [Fact].[SalesOrder] (
    OrderDateKey, CustomerKey, ProductKey, SalesAmount, Quantity, LineageKey
)
SELECT
    ISNULL(cal.[Date Key], '1753-01-01'),
    ISNULL(dc.CustomerKey, -1),
    ISNULL(dp.ProductKey, -1),
    s.SalesAmount,
    s.Quantity,
    @LineageKey
FROM [Staging].[LateArrivingSalesOrder] s
-- Resolve CustomerKey as of OrderDate (point-in-time lookup)
LEFT JOIN [Dimension].[Customer] dc
    ON  dc._SourceCustomerID    = s._SourceCustomerID
    AND CAST(s.OrderDate AS DATE) >= dc.RowEffectiveDate
    AND CAST(s.OrderDate AS DATE) <  COALESCE(dc.RowExpirationDate, '9999-12-31')
LEFT JOIN [Dimension].[Product] dp
    ON  dp._SourceProductCode   = s._SourceProductCode
    AND CAST(s.OrderDate AS DATE) >= dp.RowEffectiveDate
    AND CAST(s.OrderDate AS DATE) <  COALESCE(dp.RowExpirationDate, '9999-12-31')
LEFT JOIN [Dimension].[Calendar] cal
    ON  cal.[Date Key] = CAST(s.OrderDate AS DATE);
```

**Gotcha:** If no SCD Type 2 row covers the transaction date (data quality gap), fall back to the earliest available row for that source key:

```sql
-- Fallback: use earliest SCD row if point-in-time lookup returns NULL
LEFT JOIN [Dimension].[Customer] dc_fallback
    ON  dc_fallback._SourceCustomerID = s._SourceCustomerID
    AND dc_fallback.RowEffectiveDate = (
            SELECT MIN(RowEffectiveDate)
            FROM   [Dimension].[Customer]
            WHERE  _SourceCustomerID = s._SourceCustomerID
        )
```

---

### RowHash Change Detection Pattern

```sql
-- Compute hash of tracked attributes during staging load
-- Avoids column-by-column comparison in SCD processing
ALTER TABLE [Staging].[Employee] ADD
    RowHash AS CAST(
        HASHBYTES('SHA2_256',
            CONCAT_WS('|',
                ISNULL(LastName,  ''),
                ISNULL(FirstName, ''),
                ISNULL(DepartmentName, ''),
                ISNULL(JobTitle, '')
            )
        ) AS BINARY(32)
    ) PERSISTED;

-- In the SCD load, compare a single hash column instead of N columns
WHERE tgt.RowHash <> src.RowHash
```

### Internal Lineage Table

```sql
CREATE TABLE [Internal].[Lineage] (
    [LineageKey] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [TableName]  NVARCHAR(200) NOT NULL,
    [StartLoad]  DATETIME2(7)  NOT NULL,
    [FinishLoad] DATETIME2(7)  NULL,
    [Status]     NVARCHAR(1)   NOT NULL DEFAULT N'P',
    [Type]       NVARCHAR(1)   NOT NULL DEFAULT N'F',
    [RowCount]   BIGINT        NOT NULL DEFAULT 0
);
```

## Snapshot Schema Patterns

### Purpose
The `Snapshots` schema stores periodic and accumulating snapshots — fact table variants that record state at a point in time rather than individual transactions. Use this schema when reports need to track status changes over time (e.g. project status at end of each week, ticket status per day).

Org schema: `Snapshots` — tables live here, not in `Fact`.

### Snapshot types

#### Periodic snapshot
Records the state of a measurable entity at regular intervals (daily, weekly, monthly). Use when:
- Users want to compare values at two points in time
- Trend analysis is needed over a fixed grain

```sql
CREATE TABLE [Snapshots].[ProjectStatusWeekly]
(
    -- Degenerate dimensions (snapshot context)
    SnapshotDateKey         DATE          NOT NULL,   -- FK to Dimension.Calendar (end of week date)
    ProjectKey              INT           NOT NULL,   -- FK to Dimension.Project
    StatusKey               INT           NOT NULL,   -- FK to Dimension.ProjectStatus
    -- Measures (state at snapshot date)
    PercentComplete         DECIMAL(5,2)  NULL,
    PlannedHours            DECIMAL(10,2) NULL,
    ActualHours             DECIMAL(10,2) NULL,
    RemainingHours          DECIMAL(10,2) NULL,
    -- Audit
    LineageKey              INT           NULL        -- FK to Internal.Lineage (snapshot load run)
);
```

Load pattern: SPs named `Snapshots.Load{Entity}{Frequency}` — e.g. `Snapshots.LoadProjectStatusWeekly`

#### Accumulating snapshot
Records the complete lifecycle of a process (e.g. order fulfilment: ordered → picked → shipped → delivered). Each row is updated as the process progresses. Use when:
- A business process has a defined set of milestones
- Users want to report on lag between milestones

```sql
CREATE TABLE [Snapshots].[OrderFulfilment]
(
    -- Natural key (not surrogate — row is updated, not inserted)
    OrderID                 INT           NOT NULL,
    -- Milestone date keys (FK to Dimension.Calendar; '1753-01-01' = not yet reached — no NULLs)
    OrderDateKey            DATE          NOT NULL,
    PickedDateKey           DATE          NOT NULL,
    ShippedDateKey          DATE          NOT NULL,
    DeliveredDateKey        DATE          NOT NULL,
    -- Dimension FKs (current state)
    CustomerKey             INT           NOT NULL,
    ProductKey              INT           NOT NULL,
    StatusKey               INT           NOT NULL,   -- current status
    -- Lag measures (computed on load, stored for performance)
    DaysToPickup            INT           NULL,       -- PickedDateKey - OrderDateKey
    DaysToShip              INT           NULL,
    DaysToDeliver           INT           NULL,
    -- Audit
    LastUpdatedLineageKey   INT           NULL
);
```

Load pattern: SPs named `Snapshots.Load{Entity}` — use MERGE to update existing rows or INSERT new ones.

### Key differences from Fact tables

| | Fact | Snapshots (Periodic) | Snapshots (Accumulating) |
|---|---|---|---|
| Insert/Update | Insert only | Insert only | UPDATE existing rows |
| Row represents | A transaction event | State at a date | A business process lifecycle |
| Date keys | 1 (event date) | 1 (snapshot date) | Multiple milestone dates |
| Schema | `Fact` | `Snapshots` | `Snapshots` |
| Load SP | `Fact.Load{Entity}` | `Snapshots.Load{Entity}{Freq}` | `Snapshots.Load{Entity}` |
| Unknown member | Yes (for all FKs) | Yes | `'1753-01-01'` for unreached milestones; no NULLs |

### SSAS representation
- Periodic snapshots: exposed as a separate SSAS table via `SSAS.{Name}` view — same rules as fact SSAS views
- Accumulating snapshots: each milestone date key gets its own relationship to `Calendar` — use inactive relationships activated with `USERELATIONSHIP()` in DAX measures:

```dax
Orders Shipped This Period =
CALCULATE(
    COUNTROWS( 'Order Fulfilment' ),
    USERELATIONSHIP( 'Order Fulfilment'[Shipped Date Key], 'Calendar'[Date Key] )
)
```

### Review checklist (Mode A)
| Check | Severity if failed |
|---|---|
| Snapshots schema used (not Fact) for periodic/accumulating | 🟡 MEDIUM |
| Accumulating snapshot uses MERGE (not INSERT only) | 🟠 HIGH |
| Unreached milestone date keys use `'1753-01-01'` DATE (not NULL, 0, or -1); all date FKs are NOT NULL | 🟠 HIGH |
| SSAS views follow Title Case alias rules | 🟠 HIGH |
| Inactive relationships + USERELATIONSHIP() for multi-date accumulating | 🟡 MEDIUM |

---

## See Also

- `kimball-patterns.md` — Foundational dimensional modeling theory and planning tools
- `elt-patterns.md` — SSIS ELT implementation patterns and `Internal.Lineage` DDL
- `ssdt-project-structure.md` — SSDT project layout and publish profiles