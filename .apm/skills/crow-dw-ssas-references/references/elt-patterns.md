<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# ELT Patterns Reference — SQL Server Data Warehouse

> **This toolkit uses ELT (Extract, Load, Transform), not ETL.**
>
> In ETL, transformations happen inside the integration tool (e.g., SSIS data flows) before reaching the database.
> In ELT, raw data is loaded first into the database (staging), and all transformations happen in T-SQL
> inside the data warehouse — leveraging the SQL Server engine's full power.

---

## Upstream-First Design Philosophy (Roche's Maxim)

> **"Data should be transformed as far upstream as possible, and as far downstream as necessary."**

ELT is the practical realisation of this principle. The patterns in this file define where each class
of transformation belongs. When reviewing a pipeline or designing a new load, always place each
transformation at the highest applicable tier:

| Tier | Location | Typical transformations |
|---|---|---|
| 1 | Staging SP (`Staging.Load*`) | Type casting, null coalescing, deduplication, source key normalisation, lineage stamp |
| 2 | Dimension load SP (`Dimension.Load*`) | SCD logic, derived attributes (ABC class, age band, tenure band), surrogate key assignment |
| 3 | Fact load SP (`Fact.Load*`) | Degenerate dimensions, late-arriving grain resolution, currency conversion at load time |
| 4 | DW computed column | Simple deterministic derivations (fiscal year, quarter label) — use sparingly |
| 5 | SSAS calculated column | Display-only derivations that must exist in the model |
| 6 | DAX measure | Ad-hoc aggregations in filter context — last resort |

### Upstream Computation Examples

The following patterns are commonly attempted in DAX but belong upstream:

#### ABC Classification → `Dimension.LoadProduct` SP column

Instead of a DAX rank/SWITCH measure, add a persisted column during the dimension load:

```sql
-- In Dimension.LoadProduct (after surrogates are assigned)
UPDATE Dimension.Product
SET ABCCategory =
    CASE
        WHEN CumulativeRevenueRank <= 0.70 THEN 'A'
        WHEN CumulativeRevenueRank <= 0.90 THEN 'B'
        ELSE 'C'
    END
FROM (
    SELECT
        ProductKey,
        SUM(SalesAmount) AS TotalRevenue,
        SUM(SUM(SalesAmount)) OVER () AS GrandTotal,
        SUM(SUM(SalesAmount)) OVER (ORDER BY SUM(SalesAmount) DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) / NULLIF(SUM(SUM(SalesAmount)) OVER (), 0) AS CumulativeRevenueRank
    FROM Fact.SalesTransaction
    GROUP BY ProductKey
) ranked
WHERE Dimension.Product.ProductKey = ranked.ProductKey;
```

The SSAS layer exposes `[ABC Category]` as a plain slicer attribute. No DAX required.

#### Events in Progress → `Snapshots.ActiveEventsDaily` periodic snapshot

Instead of `FILTER(ALL('Fact Events'), [Start Date Key] <= SelectedDate && ([End Date Key] >= SelectedDate || [End Date Key] = DATE(9999,12,31)))`, load a daily snapshot:

```sql
-- Snapshots.LoadActiveEventsDaily — run nightly via SQL Agent
INSERT INTO Snapshots.ActiveEventsDaily (SnapshotDateKey, EventKey, [other dimensions...])
SELECT
    CAST(GETDATE() AS DATE) AS SnapshotDateKey,
    EventKey,
    [other dimensions...]
FROM Fact.Event
WHERE StartDateKey <= CAST(GETDATE() AS DATE)
  AND (EndDateKey >= CAST(GETDATE() AS DATE) OR EndDateKey = '9999-12-31');  -- '9999-12-31' = still open (sentinel convention)
```

The DAX measure becomes `COUNTROWS( 'Snapshots Active Events Daily' )` — simple and fast.

#### Budget Allocation (daily spreading) → `Fact.BudgetAllocated`

Instead of DAX dividing monthly budget by days-in-month, pre-spread during the fact load:

```sql
-- Fact.LoadBudgetAllocated — runs after source budget is loaded to staging
-- Spreads over working days only; join filters to IsWorkingDay = 1 so divisor and row count match
INSERT INTO Fact.BudgetAllocated ([Date Key], DepartmentKey, CostCentreKey, BudgetAmount)
SELECT
    c.[Date Key],
    b.DepartmentKey,
    b.CostCentreKey,
    b.MonthlyBudget / NULLIF(c.WorkingDaysInMonth, 0) AS BudgetAmount
FROM Staging.Budget b
JOIN Dimension.Calendar c
    ON c.Year = b.BudgetYear AND c.MonthNumber = b.BudgetMonth
WHERE c.IsWorkingDay = 1;  -- one row per working day; divisor = WorkingDaysInMonth → totals sum correctly
```

The DAX measure becomes `SUM( 'Fact Budget Allocated'[Budget Amount] )` — no division in DAX.

---

## Architecture Overview

```
┌─────────────────────┐     SSIS / source extract    ┌──────────────────────────────────────────────┐
│   SOURCE DATABASE   │ ──────────────────────────►  │           DATA WAREHOUSE DATABASE           │
│                     │   raw copy, no transforms    │                                              │
│  source extract     │                              │  ┌─────────┐   ┌──────────────────────┐      │
│  query / object     │                              │  │ Staging │ ► │ Dimension / Fact /   │ ► SSAS│
│  (@StartDate,       │                              │  │ schema  │   │ Internal schemas     │  views│
│   @EndDate)         │                              │  └─────────┘   └──────────────────────┘      │
└─────────────────────┘                              │  (T-SQL transforms everything here)          │
                                                     └──────────────────────────────────────────────┘
```

| Factor | ETL | ELT (preferred) |
|---|---|---|
| Where transforms run | SSIS data flow engine | SQL Server T-SQL engine |
| Performance on large datasets | SSIS memory-bound | SQL Server query engine |
| Maintainability | SSIS XML packages | T-SQL stored procedures |
| Debugging | SSIS debugger | SSMS, Profiler, Extended Events |
| Staging visibility | In-flight only | Queryable staging tables |
| Source system load | More transform work outside SQL | Raw extract only |
| Re-runnability | Re-run package | Re-run specific SPs |

---

## DW Schema Convention

| Schema | Purpose | Example objects |
|---|---|---|
| `Staging` | Raw data landed by SSIS; truncate/reload each run | `Staging.AdviceAndAssistance` |
| `Dimension` | Conformed dimensions and load SPs | `Dimension.Calendar`, `Dimension.LoadCalendar` |
| `Fact` | Fact tables and load SPs | `Fact.AdviceAndAssistance`, `Fact.LoadAdviceAndAssistance` |
| `Internal` | Control tables and utility SPs | `Internal.Lineage`, `Internal.IncrementalLoads` |
| `SSAS` | Views exposed to SSAS; grant `SELECT` here only | `SSAS.[Advice And Assistance]` |
| `Security` | Schema-level grants in SSDT post-deploy | `GRANT SELECT ON SCHEMA::SSAS TO [dw]` |

### SP Naming Convention

| Pattern | Example | Purpose |
|---|---|---|
| `[Schema].[Load<TableName>]` | `Fact.LoadAdviceAndAssistance` | Load DW object from staging |
| `[Schema].[Get<Resource>]` | `Internal.GetLastLoadedDate` | Lookup/helper SP |
| `[Schema].[Reset<Scope>]` | `Internal.ResetForFullLoad` | Maintenance SP |
| `Internal.RethrowError` | — | Shared CATCH rethrow |
| `Internal.ProcedureErrorInsert` | — | Error logging |
| `Source extract object` | project-specific | Source-side incremental extract query, view, or procedure |

### Internal Control Tables (project pattern)

```sql
CREATE TABLE [Internal].[Lineage] (
    [LineageKey]     INT IDENTITY (1, 1) NOT NULL PRIMARY KEY,
    [TableName]      NVARCHAR (200) NOT NULL,
    [StartLoad]      DATETIME2 (7)  NOT NULL,
    [FinishLoad]     DATETIME2 (7)  NULL,
    [LastLoadedDate] DATETIME2 (7)  NOT NULL,
    [Status]         NVARCHAR (1)   DEFAULT (N'P') NOT NULL, -- P,S,F
    [Type]           NVARCHAR (1)   DEFAULT (N'F') NOT NULL, -- F,I
    [RowCount]       BIGINT         DEFAULT ((0)) NOT NULL
);

CREATE TABLE [Internal].[IncrementalLoads] (
    [LoadDateKey] INT IDENTITY (1, 1) NOT NULL PRIMARY KEY,
    [TableName]   NVARCHAR (100) NOT NULL,
    [LoadDate]    DATETIME2 (7)  NOT NULL
);

CREATE TABLE [Internal].[LastUpdatedSource] (
    [UpdateDateKey] INT IDENTITY (1, 1) NOT NULL PRIMARY KEY,
    [TableName]     NVARCHAR (100) NOT NULL,
    [UpdateDate]    DATETIME2 (7)  NOT NULL
);

CREATE TABLE [Internal].[ProcedureError] (
    [ErrorID]        INT IDENTITY (1, 1) NOT NULL PRIMARY KEY,
    [ErrorLine]      INT             NULL,
    [ErrorMessage]   NVARCHAR (4000) NULL,
    [ErrorNumber]    INT             NULL,
    [ErrorProcedure] NVARCHAR (126)  NULL,
    [ErrorSeverity]  INT             NULL,
    [ErrorState]     INT             NULL,
    [DBName]         NVARCHAR (128)  NULL,
    [UserStamp]      NVARCHAR (50)   DEFAULT (suser_sname()) NOT NULL,
    [TimeStamp]      DATETIME        DEFAULT (getutcdate()) NOT NULL
);

CREATE TABLE [Internal].[DbVersion] (
    [VersionNumber] INT      NOT NULL,
    [Updated]       DATETIME NOT NULL DEFAULT GETDATE()
);
```

### Standard SP Error Handling Template

Every load SP uses this pattern (from `Internal.RethrowError`):

```sql
CREATE PROCEDURE [Schema].[LoadTableName]
AS
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @LastDateLoaded DATETIME2(7);
DECLARE @TableName NVARCHAR(200) = N'Schema.TableName';

BEGIN TRY
    IF @@NESTLEVEL = 1 AND @@TRANCOUNT = 0 BEGIN TRANSACTION

    DECLARE @LineageKey INT = (
        SELECT TOP(1) LineageKey FROM Internal.Lineage
        WHERE TableName = @TableName AND FinishLoad IS NULL
        ORDER BY LineageKey DESC
    );

    -- ... load logic here ...

    UPDATE Internal.Lineage
    SET FinishLoad = SYSDATETIME(), Status = 'S',
        @LastDateLoaded = LastLoadedDate, [RowCount] = @@ROWCOUNT
    WHERE LineageKey = @LineageKey;

    UPDATE Internal.IncrementalLoads
    SET LoadDate = @LastDateLoaded
    WHERE TableName = @TableName;

    IF @@NESTLEVEL = 1 AND @@TRANCOUNT > 0 COMMIT TRANSACTION
    RETURN 0

END TRY
BEGIN CATCH
    IF @@NESTLEVEL = 1 AND @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    EXECUTE Internal.RethrowError
    RETURN ERROR_NUMBER()
END CATCH
```

### Fact Load Pattern — DELETE + INSERT (preferred over MERGE)

```sql
DELETE f
FROM Fact.AdviceAndAssistance f
JOIN Staging.AdviceAndAssistance s
  ON f._SourceAdviceAndAssistanceID = s._SourceAdviceAndAssistanceID;

INSERT INTO Fact.AdviceAndAssistance (...)
SELECT d.DimKey, ISNULL(r.RegionKey, 0), ...
FROM Staging.AdviceAndAssistance s
LEFT JOIN Dimension.Calendar c ON s.ServiceStartDate = c.[Date Key]   -- LEFT JOIN: missing dates resolve to sentinel '1753-01-01'
LEFT JOIN Dimension.Region r ON s.RegionCode = r._SourceRegionCode;
```

> Prefer `DELETE + INSERT` for fact loads: simpler than `MERGE` and avoids common `MERGE` edge cases.

---

## Load Performance Heuristics

### Batch Sizing

| Scenario | Row Count | Recommended Strategy |
|---|---|---|
| Small dimension (SCD Type 1 / reference) | < 50K rows | Full truncate/reload — safe for Type 1 (no history) |
| Dimension (SCD Type 2) any size | Any | Incremental with change detection — full reload destroys history |
| Large dimension | > 500K rows | Incremental + hash-based change detection |
| Small fact table | < 5M total rows | Full reload or simple DELETE/INSERT of changed |
| Medium fact table | 5M–50M total rows | Incremental (watermark) DELETE/INSERT |
| Large fact table | > 50M total rows | Partition switching on current period (consider from 10M+ if load window is constrained) |

### Restartability

Every load SP must be **idempotent** — re-running it produces the same result as running it once:

- **Staging**: `TRUNCATE TABLE` before insert ensures clean state on retry
- **Dimensions (SCD Type 2)**: idempotent only when the load uses stable change hashes or deterministic effective dates, skips unchanged rows, and enforces one-current-row-per-natural-key (e.g., filtered unique index on `IsCurrent = 1`). Without these guards, a rerun can create duplicate current versions or shift effective dates.
- **Facts (DELETE/INSERT)**: DELETE by source key before INSERT ensures no duplicates on retry
- **Lineage**: `Internal.Lineage` Status = 'P' (pending) → 'S' (success) or 'F' (failed); failed runs leave the high-water mark unchanged so next run retries the same window

### Processing Window Budget

The nightly load window must complete with margin to spare:

| Activity | Target % of window |
|---|---|
| Source extracts (SSIS Execute SQL) | 10–20% |
| Staging → Dimension transforms | 10–15% |
| Staging → Fact transforms | 30–40% |
| SSAS ProcessData (partitions) | 20–30% |
| SSAS ProcessRecalculate | 5–10% |
| Buffer/margin | ≥ 10% |

**Rule**: If total exceeds 70% of available window, optimise the largest consumer first (usually fact loads or SSAS processing).

### Index Timing for Staging Tables

```sql
-- Pattern: add NCI AFTER bulk insert, drop before next load
-- This avoids index maintenance overhead during INSERT

-- At start of staging load:
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SalesOrder_SourceID' AND object_id = OBJECT_ID('Staging.SalesOrder'))
    DROP INDEX IX_SalesOrder_SourceID ON Staging.SalesOrder;

TRUNCATE TABLE Staging.SalesOrder;
INSERT INTO Staging.SalesOrder (...) SELECT ...;

-- After staging load completes (before dimension/fact loads use the staging table):
CREATE NONCLUSTERED INDEX IX_SalesOrder_SourceID ON Staging.SalesOrder (_SourceSalesOrderID);
```

### MAXDOP — Review-Only Note

> **Out of scope for generated code.** MAXDOP is typically controlled at the server or Resource Governor level by the DBA. These agents do **not** add `OPTION (MAXDOP N)` hints to generated queries or SPs.
>
> **During review (Mode A):** If SSAS processing queries or large ELT operations are observed competing with OLTP workloads, the agent may raise MAXDOP as a 🔵 LOW suggestion: *"Consider discussing query-level MAXDOP hints or Resource Governor workload groups with your DBA to prevent ELT/processing from starving other workloads."*

---

### Design Principles
- Source SPs are read-only.
- Accept `@StartDate` and `@EndDate` for incremental extraction.
- Return raw source columns with source names.
- Filter only to reduce volume; do not apply business rules.
- Use `NOLOCK` or RCSI to avoid blocking.
- Document extract purpose and window column with extended properties.

### Standard Source SP Pattern

```sql
CREATE PROCEDURE [Staging].[LoadCustomer]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @LineageKey INT = (SELECT TOP (1) [LineageKey] FROM [Internal].[Lineage]
        WHERE [TableName] = N'Staging.Customer' AND [FinishLoad] IS NULL
        ORDER BY [LineageKey] DESC);

    TRUNCATE TABLE [Staging].[Customer];

    INSERT INTO [Staging].[Customer] (
        [CustomerName],
        [_SourceCustomerID],
        [LineageKey]
    )
    SELECT
        src.[CustomerName],
        src.[CustomerID],
        @LineageKey
    FROM [SourceSchema].[Customer] src
    WHERE src.[ModifiedDate] >= [Internal].[GetLastLoadedDate] (N'Staging.Customer')
      AND src.[ModifiedDate] <  SYSUTCDATETIME();
END;
GO

EXEC sys.sp_addextendedproperty
    @name  = N'MS_Description',
    @value = N'Loads source customer rows into [Staging].[Customer] using the org lineage pattern.',
    @level0type = N'SCHEMA', @level0name = N'Staging',
    @level1type = N'PROCEDURE', @level1name = N'LoadCustomer';
```

### Date Window Strategy
- DW control tables define the window; source SPs never hardcode dates.
- Use a closed-open interval: `[@StartDate, @EndDate)`.
- Typical driver columns: `CreatedDate` for append-only, `ModifiedDate`/rowversion for mutable, full reload if neither exists.

### Handling Sources Without a Change Date Column
- **A. Full reload:** for small reference tables; truncate staging and reload all rows.
- **B. Row hash:** compare `HASHBYTES('SHA2_256', CONCAT(...))` in the transform layer.
- **C. Change Tracking:** lightweight SQL Server option when delete history is not required.
- **D. CDC:** use when deletes or full change history are required.

```sql
DECLARE @last_sync_version BIGINT = (
    SELECT MAX([UpdateDateKey]) FROM [Internal].[LastUpdatedSource] WHERE [TableName] = N'Staging.Customer'
);

SELECT c.*, ct.SYS_CHANGE_OPERATION
FROM CHANGETABLE(CHANGES [SourceSchema].[Customer], @last_sync_version) AS ct
JOIN [SourceSchema].[Customer] c ON ct.CustomerID = c.CustomerID;
```

---

## Layer 1c: CDC (Change Data Capture) Source Pattern

Use CDC when the source has no reliable `ModifiedDate` or when deletes must be captured.

### Enabling CDC

```sql
USE SourceDB;
EXEC sys.sp_cdc_enable_db;

EXEC sys.sp_cdc_enable_table
    @source_schema        = 'dbo',
    @source_name          = 'SalesOrder',
    @role_name            = NULL,
    @supports_net_changes = 1;
```

**Prerequisites**
- Recovery model: `FULL` or `BULK_LOGGED`
- SQL Agent running for CDC capture/cleanup jobs
- Increase cleanup retention if ELT can be down for days: `EXEC sys.sp_cdc_change_job @job_type='cleanup', @retention=7200;`
- Avoid CDC on tables with frequent DDL changes

### CDC Change Table Structure

| Column | Meaning |
|---|---|
| `__$start_lsn` | Change LSN |
| `__$seqval` | Row sequence inside transaction |
| `__$operation` | 1=Delete, 2=Insert, 3=Before-update, 4=After-update |
| `__$update_mask` | Changed-column bitmask |

### LSN-Based Load Window

```sql
DECLARE @FromLSN BINARY(10) = sys.fn_cdc_map_time_to_lsn(
    'smallest greater than or equal',
    @LastLoadTime
);
DECLARE @ToLSN BINARY(10) = sys.fn_cdc_get_max_lsn();

SELECT *
FROM cdc.fn_cdc_get_net_changes_dbo_SalesOrder(@FromLSN, @ToLSN, 'all');
-- net changes: 1=Delete, 2=Insert, 5=Update

SELECT *
FROM cdc.fn_cdc_get_all_changes_dbo_SalesOrder(@FromLSN, @ToLSN, 'all')
ORDER BY __$start_lsn, __$seqval;
```

### Transform SP Pattern for CDC Sources

```sql
CREATE PROCEDURE [Fact].[LoadSalesOrderCDC]
    @FromLSN    BINARY(10),
    @ToLSN      BINARY(10),
    @LineageKey INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;
    BEGIN TRY
        ;WITH NetChanges AS (
            SELECT *
            FROM SourceDB.cdc.fn_cdc_get_net_changes_dbo_SalesOrder(@FromLSN, @ToLSN, 'all')
        )
        DELETE f
        FROM [Fact].[SalesOrder] f
        JOIN NetChanges c ON c.SalesOrderID = f._SourceSalesOrderID
        WHERE c.__$operation = 1;

        INSERT INTO [Fact].[SalesOrder] (
            _SourceSalesOrderID,
            OrderDateKey,
            CustomerKey,
            Quantity,
            UnitPrice,
            SalesAmount,
            LineageKey
        )
        SELECT
            c.SalesOrderID,
            ISNULL(cal.[Date Key], '1753-01-01') AS OrderDateKey,   -- sentinel '1753-01-01' for missing/unknown dates
            cust.CustomerKey,
            c.Quantity,
            c.UnitPrice,
            c.Quantity * c.UnitPrice AS SalesAmount,
            @LineageKey
        FROM NetChanges c
        LEFT JOIN [Dimension].[Calendar] cal ON CAST(c.OrderDate AS DATE) = cal.[Date Key]   -- LEFT JOIN so unknown dates become sentinel
        JOIN [Dimension].[Customer] cust ON c.CustomerID = cust._SourceCustomerID AND cust.IsCurrent = 1
        WHERE c.__$operation IN (2, 5);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXECUTE [Internal].[RethrowError];
    END CATCH;
END;
GO
```

### Internal lineage tracking for CDC sources

```sql
INSERT INTO [Internal].[LastUpdatedSource] ([TableName], [UpdateDate])
VALUES (N'Fact.SalesOrder', sys.fn_cdc_map_lsn_to_time(@ToLSN));

UPDATE [Internal].[IncrementalLoads]
SET [LoadDate] = sys.fn_cdc_map_lsn_to_time(@ToLSN)
WHERE [TableName] = N'Fact.SalesOrder';
```

### CDC vs Date-Window: When to Use Each

| Factor | Date-Window SP | CDC |
|---|---|---|
| Source has `ModifiedDate` | ✅ Default | Overkill |
| Need deletes | ❌ | ✅ |
| No change date | ❌ Full reload/hash | ✅ Preferred |
| Non-SQL Server source | ✅ | ❌ |
| Recovery model = `SIMPLE` | ✅ | ❌ |
| Very high-volume tables | ✅ Low overhead | Monitor log growth |

## Salesforce / KingswaySoft Pattern

SSIS has **no native Salesforce connector**. Use **KingswaySoft SSIS Integration Toolkit**.

> Product page: https://www.kingswaysoft.com/products/ssis-integration-toolkit-for-salesforce
> Optional BIML guide: https://www.kingswaysoft.com/blog/2018/12/21/Using-BIML-with-KingswaySoft-SSIS-Components

### KingswaySoft Components

| Component | Role |
|---|---|
| **Salesforce Connection Manager** | OAuth/credential configuration |
| **Salesforce Source** | Reads via SOQL or object browser; supports Bulk API |
| **Salesforce Destination** | Writes back to Salesforce; rarely needed for DW ELT |

### Incremental Refresh via SOQL Date Filter

```
SELECT Id, Name, AccountNumber, BillingCity, BillingState, BillingPostalCode,
       Industry, AnnualRevenue, NumberOfEmployees, OwnerId, IsDeleted,
       CreatedDate, LastModifiedDate
FROM Account
WHERE LastModifiedDate >= @[User::LoadWindowStart]
  AND LastModifiedDate <  @[User::LoadWindowEnd]
```

Use SSIS expressions to inject `LoadWindowStart` and `LoadWindowEnd` from the orchestrator.

### SSIS Data Flow: Salesforce → Staging (ELT Pattern)

```
[Salesforce Source]     SOQL incremental query, Bulk API v2 for large objects
       │
       ▼
[OLE DB Destination]    [Staging].[Account]-style tables, fast load, no constraint checks
```

- No Derived Column, Lookup, Data Conversion, or Conditional Split transforms.
- Keep business logic in `Dimension.Load*` and `Fact.Load*` procedures.
- Enable Bulk API for large objects.

### Staging Table Naming for Salesforce

```sql
[Staging].[Account]
[Staging].[Contact]
[Staging].[Opportunity]
[Staging].[OpportunityLineItem]
[Staging].[Case]
[Staging].[User]
```

### Optional: BIML Code Generation for Salesforce Packages
- Use BIML only when generating many near-identical Salesforce-to-staging packages.
- Build one package manually first, then reverse-engineer it to capture correct KingswaySoft XML.
- Commit generated `.dtsx` files, not only the `.biml` source.
- `SNOW_DW` contains a working BIML example for flat-file → staging generation.

#### Critical BIML Gotchas for KingswaySoft Components

**1. Remove `System.` prefix from autogenerated data types**

```xml
<Column Name="NumberOfEmployees" DataType="System.Int32" />  <!-- wrong -->
<Column Name="NumberOfEmployees" DataType="Int32" />         <!-- correct -->
```

**2. Include `UsesDispositions="true"` on KingswaySoft source components**

```xml
<CustomComponent Name="SalesforceSource_Account"
                 ComponentClassID="{...KingswaySoft CLSID...}" />

<CustomComponent Name="SalesforceSource_Account"
                 ComponentClassID="{...KingswaySoft CLSID...}"
                 UsesDispositions="true">
```

Reverse-engineer an existing package to get the exact KingswaySoft XML attributes and `ComponentClassID` values.

### Salesforce-Specific Staging Considerations

```sql
CREATE TABLE [Staging].[Account] (
    AccountKey         INT            IDENTITY (1, 1) NOT NULL,
    AccountName        NVARCHAR(255)  NULL,
    AccountNumber      NVARCHAR(40)   NULL,
    BillingCity        NVARCHAR(40)   NULL,
    BillingState       NVARCHAR(80)   NULL,
    BillingPostalCode  NVARCHAR(20)   NULL,
    AnnualRevenue      DECIMAL(18,2)  NULL,
    NumberOfEmployees  INT            NULL,
    _SourceId          NCHAR(18)      NOT NULL,
    _SourceOwnerId     NCHAR(18)      NULL,
    CreatedDate        DATETIME       NULL,
    LastModifiedDate   DATETIME       NULL,
    LineageKey         INT            NULL,
    CONSTRAINT [PK_Account] PRIMARY KEY CLUSTERED (AccountKey ASC)
);
```

| Salesforce Type | SQL Server Staging Type |
|---|---|
| `ID` | `NCHAR(18)` |
| `String` / `TextArea` | `NVARCHAR(n)` |
| `Picklist` / `MultiPicklist` | `NVARCHAR(255)` |
| `Date` | `DATE` |
| `DateTime` | `DATETIME` |
| `Boolean` | `BIT` |
| `Integer` | `INT` |
| `Double` / `Currency` / `Percent` | `DECIMAL(18,6)` |
| `Reference` | `NCHAR(18)` |
| `Phone` / `Email` / `URL` | `NVARCHAR(255)` |

### Internal load tracking for Salesforce objects

```sql
INSERT INTO [Internal].[IncrementalLoads] ([TableName], [LoadDate])
VALUES
    (N'Staging.Account', '2000-01-01'),
    (N'Staging.Contact', '2000-01-01'),
    (N'Staging.Opportunity', '2000-01-01');
-- add remaining objects with the same pattern
```

---

## Layer 2: Staging Tables — Raw Copy Zone

### Design Principles
- Staging tables use the `Staging` schema.
- The table name matches the downstream entity name (no `stg_` prefix).
- Each staging table has its own identity `{EntityName}Key` plus `_Source...` natural keys.
- Add `LineageKey` to support load tracking.
- Truncate before each load only when the entity follows a transient staging pattern.

### Staging Table DDL Pattern

```sql
CREATE TABLE [Staging].[Customer] (
    CustomerKey        INT            IDENTITY (1, 1) NOT NULL,
    FirstName          NVARCHAR(100)  NULL,
    LastName           NVARCHAR(100)  NULL,
    Email              NVARCHAR(255)  NULL,
    Phone              NVARCHAR(50)   NULL,
    City               NVARCHAR(100)  NULL,
    CustomerTypeCode   NVARCHAR(20)   NULL,
    ModifiedDate       DATETIME       NULL,
    _SourceCustomerID  INT            NOT NULL,
    LineageKey         INT            NULL,
    CONSTRAINT [PK_Customer] PRIMARY KEY CLUSTERED (CustomerKey ASC)
);
GO

CREATE NONCLUSTERED INDEX IX_Customer_SourceCustomerID
    ON [Staging].[Customer] (_SourceCustomerID);
```

---

## Layer 3: SSIS Package Architecture

### Four-Package Structure

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Master_Orchestrator.dtsx   (runs child packages in SEQUENCE)            │
│                                                                          │
│   Step 1 ──► Load_Staging.dtsx      (all extracts run in PARALLEL)       │
│                  │                                                        │
│   Step 2 ──► Load_Dimensions.dtsx   (all dim transforms in PARALLEL)     │
│   Step 3 ──► Load_Facts.dtsx        (all fact transforms in PARALLEL)    │
└──────────────────────────────────────────────────────────────────────────┘
```

- Keep stages sequential for correctness.
- Run tasks within each stage in parallel.
- SQL Agent calls only the orchestrator.

### Package 1: `Master_Orchestrator.dtsx`

1. Log job start and get the load window.
2. Execute `Load_Staging.dtsx`.
3. On success, execute `Load_Dimensions.dtsx`.
4. On success, execute `Load_Facts.dtsx`.
5. On full success, advance the high-water mark and log success.
6. On any error, log failure and alert.

**Key configuration**
- `DelayValidation = True` on child Execute Package Tasks.
- Pass `LoadWindowStart`, `LoadWindowEnd`, and `MasterBatchID` to child packages.
- Set `MaxConcurrentExecutables = 1` at the orchestrator level.

### Package 2: `Load_Staging.dtsx`

```
All containers run IN PARALLEL:

┌─────────────────────────────┐  ┌─────────────────────────────┐  ┌─────────────────────────────┐
│ SEQ: Extract_Customer       │  │ SEQ: Extract_SalesOrder     │  │ SEQ: Extract_Product        │
│  1. TRUNCATE staging table  │  │  1. TRUNCATE staging table  │  │  1. TRUNCATE staging table  │
│  2. Data Flow: extract/load │  │  2. Data Flow: extract/load │  │  2. Data Flow: extract/load │
│  3. Log rows extracted      │  │  3. Log rows extracted      │  │  3. Log rows extracted      │
└─────────────────────────────┘  └─────────────────────────────┘  └─────────────────────────────┘
```

Each sequence container: prepare the target `Staging` table, run the source extract, land rows with fast load, and log row counts. No business transforms in the data flow.

### Package 3: `Load_Dimensions.dtsx`

Runs all dimension transform SPs in parallel via Execute SQL Tasks.
Add precedence constraints only for true dimension dependencies.

```
[Execute SQL] LoadCalendar  → EXEC [Dimension].[LoadCalendar]
[Execute SQL] LoadCustomer  → EXEC [Dimension].[LoadCustomer]
[Execute SQL] LoadProduct   → EXEC [Dimension].[LoadProduct]
-- add more dimensions in parallel
```

### Package 4: `Load_Facts.dtsx`

Runs all fact transform SPs in parallel after dimensions succeed.

```
[Execute SQL] LoadSalesOrder      → EXEC [Fact].[LoadSalesOrder]
[Execute SQL] LoadInventory       → EXEC [Fact].[LoadInventory]
[Execute SQL] LoadCustomerContact → EXEC [Fact].[LoadCustomerContact]
-- add more facts in parallel
```

### Package Deployment

```text
/ELT/
  Master_Orchestrator.dtsx
  Load_Staging.dtsx
  Load_Dimensions.dtsx
  Load_Facts.dtsx
```

Use the project deployment model (`.ispac`) with shared project-level connection managers and SSISDB environment variables.

---

## Layer 4: Internal Lineage — Orchestration

```sql
CREATE TABLE [Internal].[Lineage] (
    [LineageKey]     INT IDENTITY(1,1) PRIMARY KEY,
    [TableName]      NVARCHAR(200) NOT NULL,
    [StartLoad]      DATETIME2(7)  NOT NULL,
    [FinishLoad]     DATETIME2(7)  NULL,
    [LastLoadedDate] DATETIME2(7)  NOT NULL,
    [Status]         NVARCHAR(1)   NOT NULL DEFAULT N'P',
    [Type]           NVARCHAR(1)   NOT NULL DEFAULT N'F',
    [RowCount]       BIGINT        NOT NULL DEFAULT 0
);
GO

CREATE TABLE [Internal].[IncrementalLoads] (
    [LoadDateKey] INT IDENTITY(1,1) PRIMARY KEY,
    [TableName]   NVARCHAR(100) NOT NULL,
    [LoadDate]    DATETIME2(7)  NOT NULL
);
GO

CREATE TABLE [Internal].[LastUpdatedSource] (
    [UpdateDateKey] INT IDENTITY(1,1) PRIMARY KEY,
    [TableName]     NVARCHAR(100) NOT NULL,
    [UpdateDate]    DATETIME2(7)  NOT NULL
);
```

### Internal.Lineage — DDL and Lifecycle

```sql
CREATE TABLE [Internal].[Lineage]
(
    LineageKey      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Lineage PRIMARY KEY,
    PackageName     NVARCHAR(255)     NOT NULL,
    PackagePath     NVARCHAR(1000)    NULL,
    StartTime       DATETIME2(0)      NOT NULL CONSTRAINT DF_Lineage_StartTime DEFAULT SYSUTCDATETIME(),
    EndTime         DATETIME2(0)      NULL,
    RowsLoaded      INT               NULL,
    Status          NVARCHAR(20)      NOT NULL CONSTRAINT DF_Lineage_Status DEFAULT 'Running',
    ErrorMessage    NVARCHAR(MAX)     NULL,
    EnvironmentName NVARCHAR(50)      NULL    -- populated from SSISDB environment variable 'EnvironmentName'
);
```

Lifecycle:
1. **On package start** (Execute SQL Task, first step): `INSERT INTO [Internal].[Lineage] (PackageName, PackagePath, EnvironmentName) OUTPUT INSERTED.LineageKey INTO ?` — captures LineageKey into a package variable `User::LineageKey`
2. **On staging load** (Data Flow Task, OLE DB Destination): set `LineageKey` column from `User::LineageKey` — every staging row gets the LineageKey of the package run that loaded it
3. **On package success** (Execute SQL Task, last step): `UPDATE [Internal].[Lineage] SET EndTime = SYSUTCDATETIME(), Status = 'Success', RowsLoaded = ? WHERE LineageKey = ?`
4. **On package failure** (Event Handler → OnError): `UPDATE [Internal].[Lineage] SET EndTime = SYSUTCDATETIME(), Status = 'Failed', ErrorMessage = ? WHERE LineageKey = ?`

LineageKey FK convention:
- Every `Staging` table must have a `LineageKey INT NULL` column (nullable to allow manual loads)
- No `LineageKey` column on `Dimension` or `Fact` tables — lineage is tracked at the staging load level only
- Do NOT add `ETLBatchID`, `LoadDate`, or any other audit column pattern — `Internal.Lineage` + `Staging.LineageKey` is the only approved audit pattern

### Getting and Advancing the Date Window

```sql
CREATE PROCEDURE [Internal].[GetLineageKey]
    @TableName  NVARCHAR(200),
    @LoadType   NVARCHAR(1),
    @LineageKey INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [Internal].[Lineage] ([TableName], [StartLoad], [LastLoadedDate], [Status], [Type])
    VALUES (@TableName, SYSUTCDATETIME(), [Internal].[GetLastLoadedDate] (@TableName), N'P', @LoadType);

    SET @LineageKey = SCOPE_IDENTITY();
END;
GO

CREATE PROCEDURE [Internal].[CompleteLineage]
    @LineageKey INT,
    @RowCount   BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [Internal].[Lineage]
    SET [FinishLoad] = SYSUTCDATETIME(),
        [Status]     = N'S',
        [RowCount]   = @RowCount
    WHERE [LineageKey] = @LineageKey;
END;
```

---

## Layer 5: DW Transformation — T-SQL Stored Procedures

All business logic, type conversions, SCD handling, and DW population happens here.

### Naming Convention for Load SPs

```text
[Dimension].[Load<EntityName>]
[Fact].[Load<EntityName>]
[Staging].[Load<EntityName>]
```

Examples: `Dimension.LoadCustomer`, `Dimension.LoadCalendar`, `Fact.LoadSalesOrder`.

### Transform SP — Dimension Load (SCD Type 2)

```sql
CREATE PROCEDURE [Dimension].[LoadCustomer]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @LineageKey INT;
    EXECUTE [Internal].[GetLineageKey] @TableName = N'Dimension.Customer', @LoadType = N'I', @LineageKey = @LineageKey OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Step 1: ensure Unknown member exists
        IF NOT EXISTS (SELECT 1 FROM [Dimension].[Customer] WHERE [CustomerKey] = -1)
            INSERT INTO [Dimension].[Customer] ([CustomerKey], [_SourceCustomerID], [CustomerName], [IsCurrent], [RowEffectiveDate], [RowExpirationDate], [LineageKey])
            VALUES (-1, -1, 'Unknown', 1, '1753-01-01', '9999-12-31', NULL);

        -- Step 2: expire changed current rows
        UPDATE d
        SET d.[IsCurrent] = 0,
            d.[RowExpirationDate] = CAST(GETDATE() AS DATE),
            d.[LineageKey] = @LineageKey
        FROM [Dimension].[Customer] d
        JOIN [Staging].[Customer] s ON d.[_SourceCustomerID] = s.[_SourceCustomerID]
        WHERE d.[IsCurrent] = 1
          AND (
                d.[FirstName] <> s.[FirstName]
             OR d.[LastName]  <> s.[LastName]
             OR d.[CustomerTypeCode] <> ISNULL(s.[CustomerTypeCode], 'Unknown')
              );

        -- Step 3: insert new business keys and new Type 2 versions
        INSERT INTO [Dimension].[Customer] (
            [_SourceCustomerID], [FirstName], [LastName], [Phone], [City], [CustomerTypeCode],
            [IsCurrent], [RowEffectiveDate], [RowExpirationDate], [LineageKey]
        )
        SELECT
            s.[_SourceCustomerID], ISNULL(s.[FirstName], 'Unknown'), ISNULL(s.[LastName], 'Unknown'), s.[Phone], s.[City], s.[CustomerTypeCode],
            1, CAST(GETDATE() AS DATE), '9999-12-31', @LineageKey
        FROM [Staging].[Customer] s
        WHERE NOT EXISTS (
            SELECT 1
            FROM [Dimension].[Customer] d
            WHERE d.[_SourceCustomerID] = s.[_SourceCustomerID] AND d.[IsCurrent] = 1
        );

        COMMIT TRANSACTION;
        EXECUTE [Internal].[CompleteLineage] @LineageKey = @LineageKey, @RowCount = @@ROWCOUNT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXECUTE [Internal].[RethrowError];
    END CATCH;
END;
GO
```

### Transform SP — Fact Table Load

```sql
CREATE PROCEDURE [Fact].[LoadSalesOrder]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @LineageKey INT;
    EXECUTE [Internal].[GetLineageKey] @TableName = N'Fact.SalesOrder', @LoadType = N'I', @LineageKey = @LineageKey OUTPUT;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE f
        FROM [Fact].[SalesOrder] f
        WHERE EXISTS (
            SELECT 1
            FROM [Staging].[SalesOrder] s
            WHERE s._SourceSalesOrderID = f._SourceSalesOrderID
        );

        INSERT INTO [Fact].[SalesOrder] (
            OrderDateKey, CustomerKey, ProductKey, _SourceSalesOrderID,
            Quantity, UnitPrice, DiscountAmount, ExtendedAmount, LineageKey
        )
        SELECT
            ISNULL(cal.[Date Key], '1753-01-01'),
            ISNULL(c.CustomerKey, -1),
            ISNULL(p.ProductKey, -1),
            s._SourceSalesOrderID,
            s.Quantity,
            s.UnitPrice,
            ISNULL(s.DiscountAmount, 0),
            s.Quantity * s.UnitPrice - ISNULL(s.DiscountAmount, 0),
            @LineageKey
        FROM [Staging].[SalesOrder] s
        LEFT JOIN [Dimension].[Calendar] cal ON cal.[Date Key] = CAST(s.OrderDate AS DATE)
        LEFT JOIN [Dimension].[Customer] c ON c._SourceCustomerID = s._SourceCustomerID AND c.IsCurrent = 1
        LEFT JOIN [Dimension].[Product] p ON p._SourceProductID = s._SourceProductID AND p.IsCurrent = 1;

        COMMIT TRANSACTION;
        EXECUTE [Internal].[CompleteLineage] @LineageKey = @LineageKey, @RowCount = @@ROWCOUNT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXECUTE [Internal].[RethrowError];
    END CATCH;
END;
GO
```

---

## Layer 6: SQL Server Agent Job Orchestration

### Single Job Step — One Entry Point

```text
SQL Server Agent Job: DW_Daily_Load
Schedule: Daily at 02:00

Step 1 (only step): Run_ELT_Orchestrator
  Type:    SQL Server Integration Services Package
  Package: /SSISDB/ELT/Master_Orchestrator.dtsx
  On Success: Quit job reporting success
  On Failure: Quit job reporting failure
```

- Keep one job step only.
- Let the orchestrator handle sequencing, logging, alerts, and watermark advancement.
- Re-running the job reprocesses the same unadvanced window.

### SSAS Processing — After Facts Load

```xml
<Batch xmlns="http://schemas.microsoft.com/analysisservices/2003/engine">
  <Parallel>
    <Process xmlns:xsd="http://www.w3.org/2001/XMLSchema">
      <Object><DatabaseID>DW_Tabular</DatabaseID><DimensionID>Customer</DimensionID></Object>
      <Type>ProcessFull</Type>
    </Process>
    <Process xmlns:xsd="http://www.w3.org/2001/XMLSchema">
      <Object><DatabaseID>DW_Tabular</DatabaseID><DimensionID>Product</DimensionID></Object>
      <Type>ProcessFull</Type>
    </Process>
  </Parallel>
  <Process xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <Object><DatabaseID>DW_Tabular</DatabaseID><MeasureGroupID>SalesOrder</MeasureGroupID></Object>
    <Type>ProcessData</Type>
  </Process>
</Batch>
```

### Critical Rule: Dimensions Before Facts in SSAS Processing
- Process all dimensions first.
- Then process facts.
- Then run `ProcessRecalc` if used.
- Never process a fact before its dimensions.

### Failure Recovery Pattern

```sql
SELECT *
FROM [Internal].[Lineage]
WHERE [Status] = N'P'
  AND [StartLoad] < DATEADD(HOUR, -2, GETDATE());
```

---

## ELT Design Checklist

### Source Layer
- [ ] Source SPs accept `@StartDate` / `@EndDate` parameters
- [ ] Source SPs use `NOLOCK` or RCSI to avoid blocking production
- [ ] Source SPs are read-only — no DML
- [ ] Source SPs documented with `MS_Description` and `ExecutionContext` extended properties

### Staging Layer
- [ ] Staging tables use the `Staging` schema and schema-qualified entity names
- [ ] Staging tables follow the org pattern: `{EntityName}Key`, `_Source...` keys, `LineageKey`
- [ ] Staging tables are truncated before each load only where the documented load pattern requires it
- [ ] Staging tables have no presentation-layer FK constraints and no triggers

### SSIS Package Structure
- [ ] Four packages exist: `Master_Orchestrator`, `Load_Staging`, `Load_Dimensions`, `Load_Facts`
- [ ] `Master_Orchestrator` calls child packages in strict sequence (Staging → Dimensions → Facts)
- [ ] `Load_Staging` runs all extract tasks in parallel (no precedence constraints between extracts)
- [ ] `Load_Dimensions` runs all dimension transform SPs in parallel
- [ ] `Load_Facts` runs all fact transform SPs in parallel
- [ ] SSIS data flows contain NO transforms — raw extract to staging only
- [ ] SQL Agent job has a **single step** calling `Master_Orchestrator.dtsx` only
- [ ] Parent variables (`LoadWindowStart`, `LoadWindowEnd`, `MasterBatchID`) passed to child packages
- [ ] Project deployment model used (`.ispac`) with SSISDB environment variables for connection strings

### ELT Control & Audit
- [ ] `Internal.Lineage` tracks every load attempt with row counts and status
- [ ] `Internal.IncrementalLoads` / `Internal.LastUpdatedSource` maintain high-water marks per table
- [ ] High-water mark advances ONLY after full orchestrator success
- [ ] Job failure sends email alert via SSIS `OnError` event handler in orchestrator

### DW Transform Layer
- [ ] `Staging.Load*`, `Dimension.Load*`, and `Fact.Load*` procedures are idempotent (safe to re-run for same window)
- [ ] Load procedures use explicit transactions with `TRY/CATCH`
- [ ] Unknown/default dimension members exist (key = -1) for all dimensions
- [ ] Fact load procedures use surrogate key lookups with `ISNULL(..., -1)` fallback
- [ ] All load procedures are documented with `MS_Description` extended property

### SSAS Processing
- [ ] SSAS processing triggered from orchestrator after `Load_Facts` succeeds
- [ ] Dimensions processed before facts (enforced by XMLA batch structure)
- [ ] SSAS processing failure fails the orchestrator job and sends alert

---

## References

- James Serra: [Difference between ETL and ELT](https://www.jamesserra.com/archive/2012/01/difference-between-etl-and-elt/)
- James Serra: [Starting Your First Data Warehouse — A Practical Learning Guide](https://www.jamesserra.com/archive/2025/11/starting-your-first-data-warehouse-a-practical-learning-guide/)
- Kimball Group: *The Data Warehouse Toolkit, 3rd Edition* (Chapter 22: ETL Subsystems)
- Microsoft: [SQL Server Change Data Capture](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-data-capture-sql-server)

---

## SSIS Package Implementation Standards

### Package structure
Each SSIS package follows a three-container layout:
1. **Pre-load validation** (Sequence Container): row count check on source; abort if 0 rows and expected > 0
2. **Data flow** (Data Flow Task): source → transformations → staging OLE DB destination
3. **Post-load** (Sequence Container): update `Internal.Lineage` success record; optionally invoke load SP via Execute SQL Task

### Connection manager naming
- Naming pattern: `{SystemName}_{DatabaseName}` — e.g. `DW_DW`, `Source_Payroll`, `Source_HR`
- Connection strings are NOT hardcoded — all connection strings set from SSISDB environment variables at runtime
- Environment variable naming: `{DataSourceName}ConnectionString` — e.g. `DWConnectionString`, `PayrollConnectionString`
- Connection managers use parameterisation: `@[$Project::DWConnectionString]`

### BIML Express patterns
For packages with many similar tables, use BIML Express (Visual Studio extension) to generate packages from metadata:
- Define source/target table mappings in a metadata table or XML config
- Use BIML script to generate one `.dtsx` per source table
- Regenerate packages when schema changes — do not manually edit generated packages
- Keep BIML scripts in a `/BIML` folder within the SSIS project

### Variable naming conventions
| Variable | Scope | Purpose |
|---|---|---|
| `User::LineageKey` | Package | Lineage row PK from INSERT OUTPUT |
| `User::RowsLoaded` | Package | Count written to Lineage on success |
| `User::EnvironmentName` | Package | From SSISDB env — DEV/TEST/UAT/PROD/SUPPORT |
| `User::ErrorMessage` | Package | Captured in OnError event handler |

### Error handling
- Every package has an `OnError` event handler at the package level
- Event handler calls `Staging.RecordLineageFailure` SP (or inline Execute SQL Task) to update `Internal.Lineage`
- Never suppress errors — all errors bubble to event handler and are recorded

### Review checklist (Mode F — ELT Pipeline Review)
| Check | Severity if failed |
|---|---|
| Every staging table has `LineageKey INT NULL` column | 🟠 HIGH |
| `Internal.Lineage` INSERT on package start | 🟠 HIGH |
| `Internal.Lineage` UPDATE on success/failure | 🟠 HIGH |
| No hardcoded connection strings | 🔴 CRITICAL |
| OnError event handler present at package level | 🟠 HIGH |
| Connection managers use SSISDB env variable parameterisation | 🔴 CRITICAL |
| BIML used for bulk-similar packages | 🟡 MEDIUM |
