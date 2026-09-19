<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# Kimball Dimensional Modeling Reference

> **Authority Note:** For anything inside the SSAS Tabular semantic layer and DAX, **SQLBI (Marco Russo & Alberto Ferrari)** is the primary authority — use `sqlbi-dax-patterns.md` and `ssas-tabular-bp.md` for model and DAX design. Kimball methodology governs the **physical Data Warehouse design** (fact/dimension schema, SCD types, bus matrix, grain declaration). When Kimball guidance conflicts with SQLBI/Power BI best practices, SQLBI takes precedence for the semantic layer.

Based on Ralph Kimball's *The Data Warehouse Toolkit* (3rd ed.) and the Kimball Group methodology.
Supplemented with SQL Server 2016–2022 on-premises physical design guidance.

## Learning Resources

| Resource | Author | Format | Level | Notes |
|---|---|---|---|---|
| *The Data Warehouse Toolkit* (3rd ed.) | Ralph Kimball & Margy Ross | Book | All | Definitive reference for dimensional modeling |
| *The Data Warehouse ETL Toolkit* | Kimball & Caserta | Book | Intermediate | ETL/ELT design patterns |
| [Designing a Data Warehouse on the Microsoft SQL Server Platform](https://www.pluralsight.com/courses/sql-server-platform-designing-data-warehouse) | Ana Voicu | Pluralsight (4h 35m) | Intermediate | End-to-end: dimensional modeling → DW database → SSIS load → reports. Requires Pluralsight subscription. |
| [SQLBI.com](https://sqlbi.com) | Marco Russo & Alberto Ferrari | Website / books | All | DAX patterns, SSAS Tabular optimization, PBIX best practices |
| [daxpatterns.com](https://daxpatterns.com) | Marco Russo & Alberto Ferrari | Website | Intermediate | Ready-to-use DAX patterns library |
| [Kimball Group Design Tips](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/) | Kimball Group | Website | All | Quick reference for individual techniques |

---

## Core Vocabulary

| Term | Definition |
|---|---|
| **Grain** | The precise definition of what one row in a fact table represents. Must be declared before choosing dimensions or facts. |
| **Surrogate Key** | System-generated integer key (not business key) used as PK on all dimension tables. Enables SCD history and isolates DW from source system changes. |
| **Natural Key / Business Key** | The identifier from the source system (e.g., EmployeeID, PolicyNumber). Should be retained as an attribute but not used as FK. |
| **Conformed Dimension** | A dimension shared identically (or as a subset) across multiple fact tables, enabling drill-across queries. |
| **Conformed Fact** | A metric with a consistent definition across multiple fact tables. |
| **Bus Matrix** | An enterprise-level matrix showing which dimensions attach to which fact tables. |
| **Slowly Changing Dimension (SCD)** | A technique for tracking historical changes to dimension attributes. |
| **ODS** | Operational Data Store — a subject-oriented, integrated, volatile, current-valued store used as a staging hub before the DW. |
| **Audit Column** | System metadata columns for lineage and troubleshooting. This org uses `Internal.Lineage` + `LineageKey` (load-level lineage) — not row-level `ETLBatchID`/`RowCreatedDate` columns on every table. |
| **Late-Arriving Fact** | A fact row whose effective date falls in a past period; requires retroactive SCD Type 2 key resolution. |
| **Late-Arriving Dimension** | A dimension member that does not exist at fact load time; requires an "unknown" surrogate key placeholder. |

---

## Org Naming Conventions

Use the organisation's actual DW naming conventions when generating SQL or SSDT artifacts.

### Schema Reference

| Schema | Purpose | Replace/remove generic alternatives |
|---|---|---|
| `Dimension` | Dimension tables and their load procedures | `dbo`, `dim`, `dw`, `dimension` |
| `Fact` | Fact tables and their load procedures | `dbo`, `fact`, `dw` |
| `Staging` | Pre-processed staging tables, views, and load procedures | `stg`, `stage`, `staging` |
| `Internal` | Control, audit, helper tables, and utility procedures | `etl`, `meta`, `control`, `arch`, `audit`, `ods` |
| `SSAS` | Views used only as SSAS data sources | keep `SSAS` |
| `Security` | Roles and permissions | keep `Security` |
| `Snapshots` | Debug snapshot tables | keep `Snapshots` |

### Object and Key Rules

| Area | Org convention | Example |
|---|---|---|
| Dimension table names | Schema is the classifier; no `Dim` prefix | `[Dimension].[Calendar]`, `[Dimension].[Customer]` |
| Fact table names | Schema is the classifier; no `Fact` prefix | `[Fact].[SalesOrder]` |
| Staging table names | Same entity name across schemas; no `stg_` prefix | `[Staging].[Customer]` → `[Dimension].[Customer]` |
| Surrogate keys | `{EntityName}Key` | `CustomerKey`, `DateKey`, `LineageKey` |
| Source/natural keys | `_Source{OriginalName}` | `_SourceCustomerID`, `_SourcePartyID` |
| Date FKs in facts | `{Role}DateKey` | `OrderDateKey`, `ShipDateKey`, `ServiceStartDateKey` |
| Staging pattern | Staging tables have their own identity key plus `_Source...` columns | `[Staging].[Customer]` with `CustomerKey IDENTITY` and `_SourceCustomerID` |
| Load procedure naming | Schema-qualified `Load{EntityName}` with no `sp_`/`usp_` prefix | `Staging.LoadCustomer`, `Dimension.LoadCustomer`, `Fact.LoadSalesOrder` |
| Lineage/audit | Use `Internal.Lineage` and `LineageKey`; do not standardize on row-level `ETLBatchID`/`SourceSystemID` columns | `Internal.GetLineageKey`, `LineageKey INT NULL` |

## Fact Table Types

### Transaction Fact Table
- One row per discrete business event (sale, claim, call).
- Lowest grain; most flexible; largest rowcount.
- Design: many FK columns to dimensions, few additive measures.

### Periodic Snapshot Fact Table
- One row per entity per standard time period (daily balance, monthly inventory).
- Grain: entity + calendar period.
- Includes semi-additive measures (balances) — do **not** SUM across time in SQL; handle in DAX with `LASTNONBLANK` / `CALCULATE` (SQLBI pattern — `LASTDATE` is deprecated for this use case).

### Accumulating Snapshot Fact Table
- One row per long-lived process instance (order lifecycle, claim lifecycle).
- Multiple date FKs (OrderDate, ShipDate, DeliveryDate, etc.) — each a FK to `[Dimension].[Calendar]`.
- Rows are **updated** as milestones are reached (unique among fact tables).
- Lag measures (days between milestones) are calculated columns or DAX measures.

### Factless Fact Table
- Records the occurrence of an event with no numeric measure (student attendance, product-promotion coverage).
- Used for coverage queries: "Which products were on promotion but had zero sales?"

---

## Dimension Table Types

### Standard (Type 2) Dimension
Full history tracking. New row per change. Surrogate key FK in fact table.

### Date Dimension
- Must be pre-populated for the full date range of the DW (e.g., 1990-01-01 → 2049-12-31).
- Never use a DATETIME column as a FK. Use `DATE` typed columns — `[Date Key] DATE` — as date FKs in fact tables. This matches OLTP convention and simplifies Power BI and DAX patterns (no integer-to-date conversion needed).
- Include a separate `[YYYYMMDD] INT NOT NULL` column for sort keys and legacy compatibility.
- Include fiscal calendar attributes aligned to your organization's fiscal year.
- Include `IsWeekend`, `IsHoliday`, `FiscalQuarter`, `FiscalYear`, `RelativeDayOffset` (days from today, useful for rolling windows).

```sql
-- Minimal Date Dimension scaffold
-- NOTE: [Date Key] is DATE (not INT YYYYMMDD). [YYYYMMDD] INT is a separate column
-- for legacy joins and sort keys. All fact table date FK columns must also be DATE.
CREATE TABLE [Dimension].[Calendar] (
    [Date Key]     DATE          NOT NULL PRIMARY KEY,  -- DATE type; matches OLTP convention
    [YYYYMMDD]     INT           NOT NULL,                -- 20240415 — for sort keys and legacy joins
    [YYYYMM]       CHAR(6)       NOT NULL,                -- '202404'
    DayOfWeek      TINYINT       NOT NULL,
    DayName        VARCHAR(10)   NOT NULL,
    WeekOfYear     TINYINT       NOT NULL,
    MonthNumber    TINYINT       NOT NULL,
    MonthName      VARCHAR(10)   NOT NULL,
    CalendarQtr    TINYINT       NOT NULL,
    CalendarYear   SMALLINT      NOT NULL,
    FiscalMonth    TINYINT       NOT NULL,
    FiscalQtr      TINYINT       NOT NULL,
    FiscalYear     SMALLINT      NOT NULL,
    IsWeekend      BIT           NOT NULL DEFAULT 0,
    IsHoliday      BIT           NOT NULL DEFAULT 0,
    HolidayName    VARCHAR(50)   NULL,
    LineageKey     INT           NULL
);
```

#### Extended Business Calendar Attributes

The minimal scaffold above covers common attributes. Before generating a date dimension, **ask the user which of the following apply** — these are business and region-specific:

| Column | Type | Notes |
|---|---|---|
| `IsWorkingDay` | BIT | Derived: `IsWeekend = 0 AND IsHoliday = 0`. Drives working-day KPIs. |
| `HolidayName` | VARCHAR(50) NULL | Already in scaffold. Populated only where `IsHoliday = 1`. |
| `IsLastWorkingDayOfMonth` | BIT | Useful for month-end financial reports. |
| `IsLastDayOfMonth` | BIT | Calendar month-end flag. |
| `WeekdayName` | VARCHAR(10) | Already covered by `DayName`. Keep consistent naming. |
| `RelativeDayOffset` | INT | Days from today (negative = past). Useful for rolling windows. |
| `FiscalPeriodKey` | INT | `YYYYPP` format if org uses 13-period fiscal calendar. |
| `FiscalWeek` | TINYINT | If weekly fiscal reporting is required. |

**Holiday calendar is region-specific** — clarify with the user which applies:
- **BC Provincial**: Family Day, BC Day, Remembrance Day, plus federal statutory holidays
- **Federal Canadian**: Standard 10 federal holidays
- **Custom org calendar**: Office closures, project blackout periods, shift schedules

> **Inspect first**: Query the existing `[Dimension].[Calendar]` or equivalent before adding columns. `IsWeekend`, `IsHoliday`, and `HolidayName` are in the standard scaffold and may already exist.

### Time-of-Day Dimension
Separate from Date. Integer TimeKey in `HHMM` or seconds-since-midnight.
Only include if grain requires intra-day analysis (call center, trading).

### Role-Playing Dimension
A single physical dimension table aliased multiple times in a fact table.
Example: `[Dimension].[Calendar]` plays `OrderDateKey`, `ShipDateKey`, `DueDateKey`.
In SSAS Tabular: create inactive relationships; activate with `USERELATIONSHIP()`.

```sql
-- Fact table with role-playing date keys (DATE type — matches Calendar PK)
ALTER TABLE [Fact].[SalesOrder] ADD
    [Order Date Key]  DATE NOT NULL REFERENCES [Dimension].[Calendar]([Date Key]),
    [Ship Date Key]   DATE NOT NULL REFERENCES [Dimension].[Calendar]([Date Key]),
    [Due Date Key]    DATE NOT NULL REFERENCES [Dimension].[Calendar]([Date Key]);
```

### Junk Dimension
Combines low-cardinality flags and indicators (IsOnline, IsGift, IsRush) into a single dimension.
Pre-populate with the Cartesian product of all flag combinations.
Reduces fact table width and eliminates many tiny dimensions.

### Degenerate Dimension
A dimension attribute stored directly on the fact table (no separate dimension table).
Classic examples: Invoice Number, Order Number, Transaction ID.
Has no attributes beyond the key itself.

### Outrigger Dimension
A secondary dimension hanging off a primary dimension (avoid unless necessary).
Usually a sign of an over-normalized model. Prefer flattening into the main dimension.

### Bridge Table
Handles multi-valued dimension relationships (e.g., account–customer many-to-many).
Pattern: FactTable → BridgeTable → DimTable.
Each bridge row has a weighting factor if shares must sum to 1.0.

### Parent-Child (Ragged Hierarchy) Dimension
Recursive self-referencing structure (org chart, account hierarchy).
In Kimball: flatten to a fixed-depth dimension or use a bridge.
In SSAS Tabular: use PATH/PATHITEM DAX functions for dynamic depth.

---

## Slowly Changing Dimensions (SCD)

### Type 0 — Retain Original
Attribute never changes after first load. Source updates are ignored.
Use for: Birth Date, Original Contract Date.

### Type 1 — Overwrite
Overwrite the old value; no history retained.
Use for: Correcting typos, updating email addresses where history is irrelevant.

### Type 2 — Add New Row (Full History)
New row added for each change. Surrogate key increments.
Requires: `RowEffectiveDate`, `RowExpirationDate`, `IsCurrent` flag.

#### Standard SCD Type 2 Column Set
```sql
-- Required columns on every SCD Type 2 dimension
EmployeeKey       INT           NOT NULL IDENTITY(1,1) PRIMARY KEY,
_SourceEmployeeID INT           NOT NULL,   -- natural/business key from source
-- ... business attribute columns ...
RowEffectiveDate  DATE          NOT NULL,
RowExpirationDate DATE          NOT NULL DEFAULT '9999-12-31',
IsCurrent         BIT           NOT NULL DEFAULT 1,
LineageKey        INT           NULL
```

#### SQL Server MERGE Implementation for SCD Type 2

```sql
-- ============================================================
-- SCD Type 2 MERGE pattern for [Dimension].[Employee]
-- Assumes staging table: [Staging].[Employee]
-- ============================================================
BEGIN TRANSACTION;

-- Step 1: Expire rows where tracked attributes have changed
UPDATE [Dimension].[Employee]
SET    RowExpirationDate = CAST(GETDATE() AS DATE),
       IsCurrent         = 0,
       LineageKey        = @LineageKey
WHERE  IsCurrent = 1
  AND  _SourceEmployeeID IN (
        SELECT s._SourceEmployeeID
        FROM   [Staging].[Employee] s
        JOIN   [Dimension].[Employee] d
               ON  d._SourceEmployeeID = s._SourceEmployeeID
               AND d.IsCurrent         = 1
        WHERE  -- List every tracked (Type 2) attribute here
               d.LastName       <> s.LastName
            OR d.DepartmentName <> s.DepartmentName
            OR d.JobTitle       <> s.JobTitle
       );

-- Step 2: Insert new current rows for changed + brand-new members
INSERT INTO [Dimension].[Employee] (
    _SourceEmployeeID, FirstName, LastName, DepartmentName, JobTitle,
    RowEffectiveDate, RowExpirationDate, IsCurrent, LineageKey
)
SELECT
    s._SourceEmployeeID,
    s.FirstName,
    s.LastName,
    s.DepartmentName,
    s.JobTitle,
    CAST(GETDATE() AS DATE)  AS RowEffectiveDate,
    '9999-12-31'             AS RowExpirationDate,
    1                        AS IsCurrent,
    @LineageKey              AS LineageKey
FROM [Staging].[Employee] s
WHERE NOT EXISTS (
    SELECT 1
    FROM   [Dimension].[Employee] d
    WHERE  d._SourceEmployeeID = s._SourceEmployeeID
      AND  d.IsCurrent         = 1
);

-- Step 3: Type 1 overwrites (non-tracked attributes like email)
UPDATE d
SET    d.EmailAddress = s.EmailAddress,
       d.LineageKey   = @LineageKey
FROM   [Dimension].[Employee] d
JOIN   [Staging].[Employee]   s ON d._SourceEmployeeID = s._SourceEmployeeID
WHERE  d.IsCurrent = 1
  AND  d.EmailAddress <> s.EmailAddress;

COMMIT TRANSACTION;
```

> **Performance tip:** Add a non-clustered index on `(EmployeeNK, IsCurrent)` to accelerate the IsCurrent lookups. On large dimensions (>5M rows), consider a filtered index: `WHERE IsCurrent = 1`.

### Type 3 — Add New Column
Adds a "Previous Value" column alongside current value.
Supports only one prior change; limited history.
Use for: "Show current and prior year territory."

### Type 4 — Mini-Dimension / Rapid Change
Splits fast-changing attributes into a separate small "mini-dimension."
Fact table carries FK to both the main dimension (current SK) and the mini-dimension.
Example: Customer demographic band (age range, income tier) changes frequently.

### Type 6 — Hybrid (1+2+3)
Combines Type 1 overwrite + Type 2 new row + Type 3 prior-value column.
"Current" attribute columns are kept in sync across all rows for the natural key (Type 1 behavior).
Allows "as-was" and "as-is" reporting from the same row.

---

## Enterprise Bus Matrix

The Bus Matrix is the master blueprint of the DW. Rows = fact tables (business processes). Columns = dimensions.

| Business Process | Date | Customer | Product | Employee | Store | Order |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Sales Orders | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Returns | ✓ | ✓ | ✓ | | ✓ | ✓ |
| Inventory Snapshot | ✓ | | ✓ | | ✓ | |
| HR Headcount Snapshot | ✓ | | | ✓ | ✓ | |

**Rules:**
- Dimensions must be conformed (same surrogate key, same attributes) to enable drill-across.
- A ✓ in the matrix = a FK in the fact table.
- Build the Bus Matrix before any physical design; validate with business stakeholders.


### Canonical Output Format (Mode E)

Mode E produces a Markdown bus matrix table with this exact layout:

- **Rows**: individual fact/snapshot tables, full schema-qualified name (e.g. `Fact.SalesTransaction`)
- **Columns**: Grain (always second), then dimensions — conformed dimensions first (bold), local dimensions after
- **Cell value**: `X` = fact uses this dimension; blank = not used
- `Calendar` is always the first dimension column (always conformed)
- `Snapshots` schema tables are included alongside `Fact` schema tables
- A legend follows the table explaining bold = conformed

**Example output:**

| Fact Table | Grain | **Calendar** | **Customer** | **Product** | Region | Sales Channel |
|---|---|---|---|---|---|---|
| Fact.SalesTransaction | One row per order line | X | X | X | X | X |
| Fact.ProjectTime | One row per timesheet entry per day | X | X | | | |
| Snapshots.ProjectStatusWeekly | One row per project per week-end date | X | | | | |

**Bold** = conformed dimension (used by 2+ fact tables in this subject area)

**Rules for Mode E:**
1. Discover all tables in `Fact` and `Snapshots` schemas from the live schema or provided DDL
2. Discover all dimension tables in `Dimension` schema
3. Determine conformance by tracing foreign keys from fact/snapshot tables to dimension tables
4. Mark a dimension as conformed (bold) if 2+ fact/snapshot tables reference it
5. Sort dimension columns: conformed (bold) first, then local, alphabetically within each group
6. Derive grain from the table's primary key composition and any available extended property description
7. If grain cannot be determined automatically, prompt the user before producing the matrix
---

## Dimensional Design Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|---|---|---|
| Snowflaking dimensions | Joins at query time; no performance benefit in columnar storage | Flatten into single wide dimension |
| Using natural keys as FKs | Breaks SCD; ties DW to source system changes | Always use surrogate keys |
| Storing measures in dimension | Mixes grain; causes query complexity | Move to appropriate fact table |
| Fact table without declared grain | Ambiguous rows; incorrect aggregations | Declare grain before design |
| Nulls in FK columns | Causes SSAS relationship errors; DAX blank propagation | Use -1 "Unknown" surrogate key |
| Date stored as VARCHAR | Prevents date math; prevents `Dimension.Calendar` join | Use INT (YYYYMMDD) or DATE type |
| One big fact table (God Fact) | Violates single grain principle | Split by business process and grain |
| Over-using Type 2 SCD | Table bloat; slow lookups; SSAS processing cost | Only track attributes business needs historically |

---

## Conformed Dimension Checklist

Before declaring a dimension "conformed" across fact tables:

- [ ] Surrogate key is the same physical column (same data type, same domain).
- [ ] Natural/business key is stored as an attribute.
- [ ] Attribute names and data types are identical across all fact tables referencing this dimension.
- [ ] A single ETL process owns the dimension load (no duplicate SCD logic in multiple packages).
- [ ] The dimension is registered in the Enterprise Bus Matrix.
- [ ] A "subset" conformed dimension documents which columns are excluded for each subject area.
- [ ] The Unknown member (-1 SK) is defined with descriptive N/A values (not NULL or "Unknown").

---

## ODS (Operational Data Store) Layer

### Definition and Purpose
An **ODS** is a subject-oriented, integrated, volatile, current-valued data store that sits between source systems and the Data Warehouse. It is **not** a Data Warehouse — it holds current state only (no history by default) and is designed for operational queries and reporting with near-real-time latency.

### When to Use an ODS

| Scenario | Use ODS? |
|---|---|
| Operational staff need current-state reports (today's open orders) | ✓ Yes |
| Source system cannot be queried directly for reporting | ✓ Yes |
| Multiple source systems need to be integrated before DW load | ✓ Yes |
| Full historical analysis required | ✗ No — use DW |
| High-volume analytical queries with large date ranges | ✗ No — use DW |

### ODS vs. Staging vs. DW

| Layer | Volatility | Grain | History | Audience |
|---|---|---|---|---|
| **Staging** | Transient (truncate/reload) | Raw source rows | None — replaced each run | ETL only |
| **ODS** | Current-value, updatable | Subject-oriented, integrated | Minimal (current + 1 prior version) | Operational users, ETL feed |
| **DW (Kimball)** | Append-only (facts), SCD (dims) | Declared business grain | Full history | Analysts, BI tools |

### ODS Implementation Pattern (SQL Server)

> **Note:** This organisation does not use an ODS layer — data flows directly from `Staging` → `Dimension`/`Fact`. The ODS pattern is included for reference only.

```sql
-- ODS tables follow source structure but with integration keys
-- and audit columns. Use MERGE for upsert pattern.

CREATE TABLE ods.Customer (
    CustomerID      INT           NOT NULL PRIMARY KEY,  -- source NK
    CustomerName    VARCHAR(200)  NOT NULL,
    Email           VARCHAR(150)  NULL,
    Phone           VARCHAR(20)   NULL,
    AddressLine1    VARCHAR(200)  NULL,
    City            VARCHAR(100)  NULL,
    StateCode       CHAR(2)       NULL,
    PostalCode      VARCHAR(10)   NULL,
    -- Integration
    SourceSystemID  TINYINT       NOT NULL,
    -- Audit
    ODSInsertDate   DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),
    ODSUpdateDate   DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),
    ODSBatchID      INT           NOT NULL DEFAULT -1,
    IsActive        BIT           NOT NULL DEFAULT 1
);

-- MERGE-based ODS upsert from staging
MERGE ods.Customer AS tgt
USING stg.Customer  AS src
ON    tgt.CustomerID = src.CustomerID
  AND tgt.SourceSystemID = src.SourceSystemID
WHEN MATCHED AND (
         tgt.CustomerName <> src.CustomerName
      OR ISNULL(tgt.Email,'') <> ISNULL(src.Email,'')
      OR ISNULL(tgt.Phone,'') <> ISNULL(src.Phone,'')
    ) THEN
    UPDATE SET
        CustomerName   = src.CustomerName,
        Email          = src.Email,
        Phone          = src.Phone,
        ODSUpdateDate  = SYSUTCDATETIME(),
        ODSBatchID     = @BatchID
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CustomerID, CustomerName, Email, Phone,
            SourceSystemID, ODSInsertDate, ODSUpdateDate, ODSBatchID)
    VALUES (src.CustomerID, src.CustomerName, src.Email, src.Phone,
            src.SourceSystemID, SYSUTCDATETIME(), SYSUTCDATETIME(), @BatchID)
WHEN NOT MATCHED BY SOURCE AND tgt.SourceSystemID = @SourceSystemID THEN
    UPDATE SET IsActive = 0, ODSUpdateDate = SYSUTCDATETIME();
```

### Layer Architecture (Three-Layer)
```
Source Systems
     │
     ▼
┌──────────────┐   Truncate/reload each run
│   Staging    │   Staging schema
└──────────────┘
     │
     ▼
┌──────────────┐   Reference pattern only
│ *(not used)* │   ODS layer is not used in this organisation
└──────────────┘
     │
     ▼
┌──────────────┐   SCD / key resolution / star schema
│ Dimension /  │   Dimension / Fact schemas
│ Fact schemas │
└──────────────┘
     │
     ▼
┌──────────────┐
│ SSAS views + │   SSAS views + Tabular
│   Tabular    │
└──────────────┘
```

---

## Audit / Lineage Standard

This organisation uses **load-level lineage** rather than standardizing `RowCreatedDate`, `ETLBatchID`, or `SourceSystemID` on every table row.

| Object / Column | Purpose | Notes |
|---|---|---|
| `Internal.Lineage` | Tracks load start/finish, status, type, and row count per table | Use `LineageKey`, `TableName`, `StartLoad`, `FinishLoad`, `Status`, `Type`, `RowCount` |
| `Internal.IncrementalLoads` | Tracks incremental load dates | Maintained after successful loads |
| `Internal.LastUpdatedSource` | Tracks source-system last updated timestamps | Used for incremental orchestration |
| `Internal.ProcedureError` | Logs stored procedure failures | Pair with `Internal.RethrowError` |
| `LineageKey` | Captures the load execution on staging and related objects | Prefer `LineageKey INT NULL` over batch-ID columns |

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

---

## NULL Handling Strategy

### Core Rule
**No NULLs in surrogate key (FK) columns in fact tables.** NULLs in FK columns cause SSAS relationship violations and inconsistent DAX aggregation behavior.

### Standard NULL Substitution Values

> **SQLBI simplification:** Use a single **Unknown** sentinel (`-1`) for all unknown/missing FK scenarios. Multiple sentinel values (-2 Not Applicable, -3 Pending, etc.) add model complexity without benefit in DAX — a single unknown member appears as `(Blank)` in slicers regardless of its label, and SSAS filter contexts do not distinguish between multiple sentinel rows.

| Scenario | Surrogate Key | Descriptive Attributes |
|---|---|---|
| FK lookup fails, member not found, or N/A | `-1` (Unknown) | `'Unknown'` |

If business reporting genuinely requires distinguishing "Not Applicable" from "Unknown", use a **Status attribute** on the fact or the dimension row, not multiple sentinel surrogate keys.

### Dimension Unknown Member Setup

```sql
-- Every dimension must have the Unknown sentinel row
-- Insert with IDENTITY_INSERT ON (see Surrogate Key section)
SET IDENTITY_INSERT [Dimension].[Customer] ON;
INSERT INTO [Dimension].[Customer] (
    CustomerKey, _SourceCustomerID, CustomerName, City, StateCode,
    RowEffectiveDate, RowExpirationDate, IsCurrent, LineageKey
) VALUES
    (-1, -1, 'Unknown', 'Unknown', 'XX', '1753-01-01', '9999-12-31', 1, NULL);
SET IDENTITY_INSERT [Dimension].[Customer] OFF;
```

### NULL Handling in Measures (Fact Columns)

- Additive measures (SalesAmount, Quantity): use `0` not NULL — NULL propagates through SUM differently from 0 in DAX.
- Semi-additive measures (Balance): `NULL` is valid and semantically correct — use `LASTNONBLANK` in DAX, not `LASTDATE`.
- Ratio denominators: keep `NULL` and handle division-by-zero in DAX with `DIVIDE()`.

```sql
-- Fact table measure column pattern
SalesAmount    DECIMAL(18,4) NOT NULL DEFAULT 0,    -- additive: no NULLs
CostAmount     DECIMAL(18,4) NOT NULL DEFAULT 0,    -- additive: no NULLs
EndingBalance  DECIMAL(18,4)     NULL,              -- semi-additive: NULL = no record for period
```

---

## ETL / Staging Pattern

### Layer Responsibilities

| Layer | Schema | Responsibility |
|---|---|---|
| Staging | `Staging` | Pre-processed staging tables, views, and load procedures |
| ODS | `*(not used)*` | This organisation loads directly from `Staging` to `Dimension` / `Fact` |
| Dimensions | `Dimension` | SCD processing and surrogate key assignment |
| Facts | `Fact` | Surrogate key lookup and fact loading |
| Internal | `Internal` | Lineage, incremental load tracking, errors, rejects, and helper procedures |

### Staging Pattern (SQL Server)

```sql
-- Staging tables: org pattern uses schema-qualified entity names
CREATE TABLE [Staging].[Customer] (
    CustomerKey       INT           IDENTITY (1, 1) NOT NULL,
    CustomerName      VARCHAR(200)  NOT NULL,
    Email             VARCHAR(150)  NULL,
    _SourceCustomerID INT           NOT NULL,
    LineageKey        INT           NULL,
    CONSTRAINT [PK_Customer] PRIMARY KEY CLUSTERED (CustomerKey ASC)
);

-- Truncate before each load when the staging pattern is transient
TRUNCATE TABLE [Staging].[Customer];
```

### Reject / Error Row Handling

```sql
-- Capture rejected rows for investigation in the Internal schema
CREATE TABLE [Internal].[FactSalesOrder_Rejects] (
    -- All columns of [Staging].[SalesOrder]
    RejectReason    VARCHAR(500)  NOT NULL,
    RejectDate      DATETIME2(0)  NOT NULL DEFAULT SYSUTCDATETIME(),
    LineageKey      INT           NOT NULL
);

-- During fact load: capture rows that could not be resolved
INSERT INTO [Internal].[FactSalesOrder_Rejects]
SELECT s.*, 'CustomerKey not resolvable', SYSUTCDATETIME(), @LineageKey
FROM [Staging].[SalesOrder] s
WHERE NOT EXISTS (
    SELECT 1 FROM [Dimension].[Customer] dc
    WHERE dc._SourceCustomerID = s._SourceCustomerID AND dc.IsCurrent = 1
);
```

---

## See Also — Advanced Implementation Patterns

The following topics are covered in `kimball-advanced-patterns.md`:

- Data Vault 2.0 awareness and Kimball vs. Data Vault comparison
- SQL Server physical design (columnstore indexes, partitioning, filegroups, statistics)
- Surrogate key generation strategies (IDENTITY, SEQUENCE, MERGE-based)
- Late-arriving dimension members and late-arriving facts
- RowHash change detection pattern
- Snapshot schema patterns (periodic and accumulating snapshots)
