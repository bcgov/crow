<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# SQLBI DAX Patterns — Advanced (Medium Likelihood)

Situational patterns used when the project scenario requires them. Reference when Mode D or Mode L encounters the relevant scenario.

---

## 3. Many-to-Many Relationships

### Bridge Table (CL 1200+)
Relationships: `Sales → BridgeCustomerGroup` (Both), `BridgeCustomerGroup → DimCustomer` (Single).

```dax
Sales M2M :=
CALCULATE(
    [Total Sales],
    TREATAS(
        SUMMARIZE( DimCustomer, DimCustomer[CustomerKey] ),
        BridgeCustomerGroup[CustomerKey]
    )
)
```

### Native M2M (CL 1500+)
Setting relationship cross-filter to **Both** directly is **not recommended** — it causes explosive filter expansion on large tables and makes row context ambiguous. Use the `TREATAS` bridge pattern above for all M2M scenarios.

> **SQLBI standard:** Always use bridge table + `TREATAS` for many-to-many. Native bidirectional M2M is a last resort for small reference tables only.

---

## 4. Calculation Groups (CL 1500+)

> Requires `TabularEditor.exe` (Tabular Editor 2.x). Not available in SSDT. Not available below CL 1500.

```dax
-- Calculation Item: "Actual"
SELECTEDMEASURE()

-- Calculation Item: "YTD"
CALCULATE( SELECTEDMEASURE(), DATESYTD( 'Calendar'[Date Key] ) )

-- Calculation Item: "YTD Fiscal"  (Apr 1 – Mar 31; fiscal year-end = Mar 31)
CALCULATE( SELECTEDMEASURE(), DATESYTD( 'Calendar'[Date Key], "03-31" ) )

-- Calculation Item: "SPLY"
CALCULATE( SELECTEDMEASURE(), SAMEPERIODLASTYEAR( 'Calendar'[Date Key] ) )

-- Calculation Item: "YoY %"
VAR Curr = CALCULATE( SELECTEDMEASURE() )
VAR Prev = CALCULATE( SELECTEDMEASURE(), SAMEPERIODLASTYEAR( 'Calendar'[Date Key] ) )
RETURN DIVIDE( Curr - Prev, Prev )

-- Calculation Item: "R12M"
CALCULATE( SELECTEDMEASURE(), DATESINPERIOD( 'Calendar'[Date Key], LASTDATE( 'Calendar'[Date Key] ), -12, MONTH ) )

-- Format String Expression on YoY % item:
"0.0%"

-- Conditional: apply only to named measures (use SELECTEDMEASURENAME())
IF(
    SELECTEDMEASURENAME() IN { "Total Sales", "Total Cost", "Gross Profit" },
    CALCULATE( SELECTEDMEASURE(), SAMEPERIODLASTYEAR( 'Calendar'[Date Key] ) ),
    SELECTEDMEASURE()
)
```

| Feature | CL 1500 (2019) | CL 1600 (2022) |
|---|---|---|
| Calculation Groups | ✅ | ✅ |
| Format String Expressions | ✅ | ✅ |
| Dynamic format on base measures | ❌ | ✅ |
| CALCULATION() function | Limited | ✅ |
| Authoring in SSDT | ❌ | ❌ |

**Precedence:** Lower number = higher priority (evaluated last). When using multiple groups (e.g. Time Intelligence + Currency), set Precedence carefully and test with `SELECTEDMEASURENAME()`.

---

## 5. Disconnected Tables / Parameter Tables

```dax
-- DimScenario: ScenarioKey (1/2/3), ScenarioName. Not related to any fact table.
Selected Scenario Sales :=
VAR Sel = SELECTEDVALUE( DimScenario[ScenarioKey], 3 ) -- default: Actual
RETURN SWITCH( Sel,
    1, [Budget Sales], 2, [Forecast Sales], 3, [Actual Sales], [Actual Sales] )

-- Dynamic measure switch (use when calc groups unavailable at CL 1200)
Dynamic KPI :=
SWITCH( SELECTEDVALUE( DimKPI[KPIKey] ),
    1, [Total Sales], 2, [Total Cost], 3, [Gross Profit], 4, [Units Sold], BLANK() )
```

---

## 6. Ranking Patterns

```dax
Product Sales Rank :=
IF( ISBLANK( [Total Sales] ), BLANK(),
    RANKX( ALLSELECTED( 'Product'[Product Name] ), [Total Sales],, DESC, DENSE ) )

-- Top N filter (use in visual-level filter: [Is Top N] = 1)
Is Top N :=
VAR N = SELECTEDVALUE( DimTopN[N], 10 )
RETURN IF( [Product Sales Rank] <= N, 1, 0 )
```

---

## 7. Parent-Child Hierarchies

SSAS Tabular has no native ragged/recursive hierarchy support. Flatten using PATH computed columns at model refresh.

```dax
-- Computed columns on DimEmployee:
EmployeePath  = PATH( DimEmployee[EmployeeKey], DimEmployee[ManagerKey] )
EmployeeDepth = PATHLENGTH( DimEmployee[EmployeePath] )
Level1Key     = PATHITEM( DimEmployee[EmployeePath], 1, INTEGER )
Level2Key     = PATHITEM( DimEmployee[EmployeePath], 2, INTEGER )
Level3Key     = PATHITEM( DimEmployee[EmployeePath], 3, INTEGER )
Level1Name    = LOOKUPVALUE( DimEmployee[EmployeeName], DimEmployee[EmployeeKey], DimEmployee[Level1Key] )
Level2Name    = LOOKUPVALUE( DimEmployee[EmployeeName], DimEmployee[EmployeeKey], DimEmployee[Level2Key] )

-- Rollup all subordinates of selected employee
Subordinate Sales :=
CALCULATE( [Total Sales],
    FILTER( DimEmployee,
        PATHCONTAINS( DimEmployee[EmployeePath], MAX( DimEmployee[EmployeeKey] ) ) ) )
```

---

## 11. Error Handling in DAX

```dax
-- ✅ Always DIVIDE() — never / operator
Safe Ratio            := DIVIDE( [Numerator], [Denominator] )       -- returns BLANK on zero
Safe Ratio (0 default) := DIVIDE( [Numerator], [Denominator], 0 )

-- ❌ Avoid — errors in reports
Unsafe Ratio := [Numerator] / [Denominator]

-- IFERROR for lookup fallbacks
Safe Lookup :=
IFERROR( LOOKUPVALUE( 'Product'[Standard Cost], 'Product'[Product Key], MAX( 'Fact Sales'[Product Key] ) ), 0 )

-- ISBLANK (preferred over = BLANK() for measures)
Has Sales := NOT ISBLANK( [Total Sales] )

-- COALESCE: first non-blank value (CL 1550+ / SSAS 2022 only)
-- For CL 1500: use nested IF( ISBLANK(...), ..., ... ) instead
Effective Price        := COALESCE( [Override Price], [Standard Price], 0 )
Product Category Safe  := COALESCE( SELECTEDVALUE( 'Product'[Category] ), "Unknown" )

-- Return BLANK (not 0) for no-match rows — cleaner in visuals
Total Sales (Clean) := IF( COUNTROWS( 'Fact Sales' ) = 0, BLANK(), SUM( 'Fact Sales'[Sales Amount] ) )
```

---

## 13. Aggregation Tables (User-Defined, CL 1500+)

> **TE3 / Premium / Fabric feature note:** Automatic aggregations require Tabular Editor 3 (paid) and/or Power BI Premium/Fabric. On-prem SSAS has **no automatic aggregations** — the pattern below uses manually configured user-defined aggregations via `TabularEditor.exe` (TE2).

**Use when:** fact table >50–100M rows with repeating summary queries at coarser grain (month/region/category).

```sql
-- Step 1: Create agg table in DW (refreshed nightly)
CREATE TABLE [Fact].[Sales_Agg_MonthRegion] (
    DateMonthKey  DATE         NOT NULL,   -- first day of month: DATEFROMPARTS(YEAR, MONTH, 1)
    RegionKey     INT          NOT NULL,
    ProductCatKey INT          NOT NULL,
    TotalSales    DECIMAL(18,2) NOT NULL,
    TotalCost     DECIMAL(18,2) NOT NULL,
    TotalUnits    INT          NOT NULL,
    CONSTRAINT PK_FactSales_Agg PRIMARY KEY (DateMonthKey, RegionKey, ProductCatKey)
);

INSERT INTO [Fact].[Sales_Agg_MonthRegion]
SELECT DATEFROMPARTS(YEAR(d.[Date Key]), MONTH(d.[Date Key]), 1),
       f.RegionKey, p.CategoryKey,
    SUM(f.SalesAmount), SUM(f.CostAmount), SUM(f.Units)
FROM [Fact].[Sales] f
JOIN [Dimension].[Calendar] d ON f.[Order Date Key] = d.[Date Key]
JOIN [Dimension].[Product] p ON f.ProductKey = p.ProductKey
GROUP BY DATEFROMPARTS(YEAR(d.[Date Key]), MONTH(d.[Date Key]), 1), f.RegionKey, p.CategoryKey;
```

```json
// Step 2: In Tabular Editor — set alternateOf on agg table columns (partial BIM)
{
  "name": "TotalSales", "summarizeBy": "sum",
  "alternateOf": { "tableName": "Sales", "columnName": "SalesAmount", "summarization": "Sum" }
}
```

**Rules:** Agg table must be **hidden**. Grain ≥ detail fact grain. Relationships mirror detail fact. Verify via DAX Studio Server Timings → `VertiPaq Scan` hitting agg table name.

---

## 14. DAX for Paginated Report Parameters (PBIRS/SSRS)

Use `@ParamName` syntax in SSRS dataset query text mode. Use integer year/month params to avoid date parsing issues.

```dax
-- Parameterised dataset (params: @StartYear, @StartMonth, @EndYear, @EndMonth)
EVALUATE
CALCULATETABLE(
    SUMMARIZECOLUMNS(
        'Product'[Product Name], 'Product'[Category],
        'Calendar'[Calendar Year], 'Calendar'[Month Name],
        "Total Sales", [Total Sales], "Total Cost", [Total Cost],
        "Gross Profit", [Gross Profit], "Units Sold", [Units Sold]
    ),
    Calendar[Date Key] >= DATE(@StartYear, @StartMonth, 1),
    Calendar[Date Key] <= EOMONTH( DATE( @EndYear, @EndMonth, 1 ), 0 )  -- EOMONTH handles months shorter than 31 days
)
ORDER BY 'Calendar'[Calendar Year], 'Calendar'[Month Name], 'Product'[Product Name]

-- Measure selector (@MeasureSelector: 1=Sales, 2=Cost, 3=Profit)
EVALUATE CALCULATETABLE(
    ADDCOLUMNS( SUMMARIZE( 'Product', 'Product'[Product Name], 'Product'[Category] ),
        "Value", SWITCH( @MeasureSelector, 1, [Total Sales], 2, [Total Cost], 3, [Gross Profit], [Total Sales] ) ) )

-- Cascading param: years with data
EVALUATE SUMMARIZECOLUMNS( 'Calendar'[Calendar Year], "HasData", CALCULATE( COUNTROWS( 'Fact Sales' ) ) )
ORDER BY 'Calendar'[Calendar Year] ASC

-- Cascading: regions for selected year
EVALUATE CALCULATETABLE(
    SUMMARIZECOLUMNS( 'Region'[Region Name], 'Region'[Region Key] ),
    'Calendar'[Calendar Year] = @SelectedYear )
ORDER BY 'Region'[Region Name]
```

---

## 15. VertiPaq vs. Formula Engine Optimisation

| Component | Role | Parallelism |
|---|---|---|
| **Storage Engine (SE)** | Scans VertiPaq columnar data; simple aggregations | ✅ Multi-threaded |
| **Formula Engine (FE)** | DAX logic, iterators, context transitions | ❌ Single-threaded |

**Golden rule:** Push work to SE. FE bottleneck = no benefit from extra CPU.

**Diagnose in DAX Studio:** Server Timings → SE CPU vs. FE time. SE-dominant (≥80% SE) = good.
High FE + many SE Queries = `Callback DataID` (SE calling FE per row).
Caused by: measures inside FILTER/SUMX, nested iterators, measures referencing measures in row context.

```
Good (SE-dominant): Total 450ms | SE 420ms (93%) | FE 30ms | SE Queries: 4
Bad  (FE-dominant): Total 3200ms | SE 80ms | FE 3120ms (98%) | SE Queries: 847
```

```dax
-- ❌ FILTER with measure — FE per row (CallbackDataID)
CALCULATE( [Total Sales], FILTER( 'Product', [Product Margin %] > 0.2 ) )

-- ✅ FILTER with column — stays in SE
CALCULATE( [Total Sales], FILTER( 'Product', 'Product'[Standard Margin] > 0.2 ) )

-- ❌ SUMX + LOOKUPVALUE per row — FE
SUMX( 'Fact Sales', 'Fact Sales'[Qty] * LOOKUPVALUE( 'Product'[Price], 'Product'[Product Key], 'Fact Sales'[Product Key] ) )

-- ✅ Pre-calculated column or relationship
Fast SUM := SUM( 'Fact Sales'[Pre Calc Revenue] )
```

**VertiPaq compression tips:**
1. Sort partition query `ORDER BY` highest-cardinality column — better run-length encoding.
2. Avoid full timestamps when date-only sufficient; avoid free-text model columns.
3. Use integer keys, not string keys.

```dax
-- DMV: memory by column (DAX Studio → DMV mode against SSAS)
SELECT MEASURE_GROUP_NAME AS TableName, ATTRIBUTE_NAME AS ColumnName,
    ROWS_COUNT, USED_SIZE AS MemoryBytes, DICTIONARY_SIZE
FROM $SYSTEM.DISCOVER_STORAGE_TABLE_COLUMN_SEGMENTS
ORDER BY USED_SIZE DESC
```

---

## 19. Bus Matrix Validation in DAX

```dax
-- Verify Product conforms across both fact tables
Product in Sales Count :=
CALCULATE( DISTINCTCOUNT( 'Fact Sales'[Product Key] ), ALLEXCEPT( 'Product', 'Product'[Product Key] ) )

Product in Returns Count :=
CALCULATE( DISTINCTCOUNT( 'Fact Returns'[Product Key] ), ALLEXCEPT( 'Product', 'Product'[Product Key] ) )

-- Orphan check: fact keys with no dimension match (run in DAX Studio)
EVALUATE
FILTER(
    ADDCOLUMNS( VALUES( 'Fact Sales'[Product Key] ),
        "In Product",
        CALCULATE( COUNTROWS( 'Product' ), 'Product'[Product Key] = EARLIER( 'Fact Sales'[Product Key] ) ) ),
    [In Product] = 0
)
```

---

## Static Segmentation

**Source:** https://www.daxpatterns.com/static-segmentation/
**Likelihood:** 🟡 Medium — age bands, cost tiers, project size categories

Classifies a numeric value into a fixed set of ranges defined in a separate table.

### Data model
Create a `Dimension.Segment` table with `MinValue`, `MaxValue`, `SegmentLabel` columns. Use a disconnected relationship or `TREATAS` to apply.

### Pattern
```dax
Segment Label =
VAR CurrentValue = [Total Sales Amount]
RETURN
CALCULATE(
    MAX( 'Segment'[Segment Label] ),
    FILTER(
        'Segment',
        'Segment'[Min Value] <= CurrentValue
        && 'Segment'[Max Value] > CurrentValue
    )
)
```

---

## Dynamic Segmentation and ABC Classification

**Source:** https://www.daxpatterns.com/dynamic-segmentation/ and https://www.daxpatterns.com/abc-classification/
**Likelihood:** 🟡 Medium — client tiering, product ABC analysis, resource classification

Dynamic segmentation classifies entities based on a calculated measure value (which changes with filter context). ABC groups entities where A = top contributors to X% of total.

### ABC Pattern
```dax
ABC Class =
VAR EntityValue    = [Total Sales Amount]
VAR AllEntities    = ALLSELECTED( 'Customer' )
VAR TotalValue     = CALCULATE( [Total Sales Amount], AllEntities )
VAR CumulativeRank =
    COUNTROWS(
        FILTER(
            AllEntities,
            CALCULATE( [Total Sales Amount] ) >= EntityValue
        )
    )
VAR CumulativeShare =
    DIVIDE(
        SUMX(
            TOPN( CumulativeRank, AllEntities, [Total Sales Amount] ),
            [Total Sales Amount]
        ),
        TotalValue,
        BLANK()
    )
RETURN
SWITCH(
    TRUE(),
    CumulativeShare <= 0.70, "A",
    CumulativeShare <= 0.90, "B",
    "C"
)
```
**Note:** ABC classification is expensive on large dimensions. Pre-calculate as a calculated column if the filter context is always the full dataset.

---

## Related Distinct Count

**Source:** https://www.daxpatterns.com/related-distinct-count/
**Likelihood:** 🟡 Medium — distinct customers per region, distinct projects per department

Counts distinct values in a dimension considering only rows that have related transactions in the fact table.

### Pattern
```dax
Active Customers =
DISTINCTCOUNT( 'Fact SalesTransaction'[Customer Key] )

-- Distinct count of a dimension attribute (not FK column):
Active Customer Regions =
CALCULATE(
    DISTINCTCOUNT( 'Customer'[Region] ),
    SUMMARIZE( 'Fact SalesTransaction', 'Customer'[Region] )
)
```

---

## Comparing Different Time Periods (User-Defined)

**Source:** https://www.daxpatterns.com/comparing-different-time-periods/
**Likelihood:** 🟡 Medium — ad hoc period comparison (e.g. "this quarter vs same quarter 2 years ago")

Uses a disconnected `Period` slicer table to let users select two periods to compare.

### Pattern
```dax
Period 1 Sales =
CALCULATE(
    [Total Sales Amount],
    TREATAS(
        VALUES( 'Period1Selector'[Date] ),
        'Calendar'[Date]
    )
)

Period 2 Sales =
CALCULATE(
    [Total Sales Amount],
    TREATAS(
        VALUES( 'Period2Selector'[Date] ),
        'Calendar'[Date]
    )
)

Period Variance =
[Period 1 Sales] - [Period 2 Sales]
```

---

## Transition Matrix

**Source:** https://www.daxpatterns.com/transition-matrix/
**Likelihood:** 🟡 Medium — project status changes, ticket state transitions, customer status tracking

Analyses how entities move between states over time. Requires a periodic snapshot with current and previous state.

### Data model
`Snapshots.EntityStatusWeekly` with `CurrentStatusKey` and `PreviousStatusKey` (both FK to `Dimension.Status`).

### Pattern
```dax
Transitions Count =
CALCULATE(
    COUNTROWS( 'Snapshots EntityStatusWeekly' ),
    USERELATIONSHIP( 'Snapshots EntityStatusWeekly'[Current Status Key], 'Status'[Status Key] )
)

-- Used in a matrix visual: rows = Previous Status, columns = Current Status
```

---

## Month and Week Calculations (Non-Standard Fiscal Calendar)

**Source:** https://www.daxpatterns.com/month-related-calculations/ and https://www.daxpatterns.com/week-related-calculations/
**Likelihood:** 🟡 Medium — required only when the org uses a **non-standard fiscal calendar** (week-based, 4-4-5, 4-5-4, 5-4-4, 13-period, ISO-week, or any calendar that does not align to month-end boundaries)

### When to use built-in DAX time intelligence vs. filter-based patterns

| Fiscal calendar type | Pattern to use |
|---|---|
| **Standard month-aligned fiscal year** (e.g. Apr 1 – Mar 31, Jul 1 – Jun 30, Oct 1 – Sep 30) | Use built-in `DATESYTD( 'Calendar'[Date Key], "MM-DD" )` with the fiscal year-end month/day. The org standard pattern for Apr 1 – Mar 31 is `DATESYTD( 'Calendar'[Date Key], "03-31" )`. See `sqlbi-dax-patterns.md` and `dax-style-guide.md`. |
| **Week-based, 4-4-5, 4-5-4, 5-4-4, 13-period, or ISO-week fiscal calendar** | Built-in DAX time intelligence breaks for these because period boundaries do not align to month-end. Use the filter-based patterns below. |

> **Org default (Apr 1 – Mar 31):** the standard `DATESYTD(..., "03-31")` pattern works correctly. Do not use the filter-based patterns in this section unless the project explicitly requires a non-standard calendar.

The filter-based patterns below assume the org uses a non-standard fiscal calendar.

### Fiscal YTD (non-standard calendar only)
```dax
Fiscal YTD Sales =
CALCULATE(
    [Total Sales Amount],
    FILTER(
        ALL( 'Calendar' ),
        'Calendar'[Fiscal Year Number] = MAX( 'Calendar'[Fiscal Year Number] )
        && 'Calendar'[Fiscal Day of Year] <= MAX( 'Calendar'[Fiscal Day of Year] )
    )
)
```

### Fiscal Prior Year (non-standard calendar only)
```dax
Fiscal Prior Year Sales =
CALCULATE(
    [Total Sales Amount],
    FILTER(
        ALL( 'Calendar' ),
        'Calendar'[Fiscal Year Number] = MAX( 'Calendar'[Fiscal Year Number] ) - 1
        && 'Calendar'[Fiscal Week Number] <= MAX( 'Calendar'[Fiscal Week Number] )
    )
)
```

**Prerequisite:** `Calendar` table must include `Fiscal Year Number`, `Fiscal Week Number`, `Fiscal Day of Year` columns. If these are absent, raise a 🟠 HIGH finding in Mode A.

---

## Like-for-Like Comparison

**Source:** https://www.daxpatterns.com/like-for-like-comparison/
**Likelihood:** 🟡 Medium — comparable period analysis excluding new/closed entities

Restricts a period comparison to entities (stores, projects, products) that existed in BOTH periods — eliminating the distortion caused by new entrants or closures.

### Pattern
```dax
Like-for-Like Sales =
VAR CurrentPeriodEntities =
    CALCULATETABLE(
        VALUES( 'Fact SalesTransaction'[Customer Key] ),
        DATESYTD( 'Calendar'[Date] )
    )
VAR PriorPeriodEntities =
    CALCULATETABLE(
        VALUES( 'Fact SalesTransaction'[Customer Key] ),
        SAMEPERIODLASTYEAR( DATESYTD( 'Calendar'[Date] ) )
    )
VAR CommonEntities =
    INTERSECT( CurrentPeriodEntities, PriorPeriodEntities )
RETURN
CALCULATE(
    [Total Sales Amount],
    KEEPFILTERS( CommonEntities )
)
```

---

## Natural Hierarchies (Ragged and Balanced)

**Source:** https://www.daxpatterns.com/hierarchies/
**Likelihood:** 🟡 Medium — geography (Country → Region → City), org structure, product categories

### Balanced hierarchy (fixed depth)
Define as a standard SSAS Tabular hierarchy on the dimension table. No special DAX needed — VertiPaq handles it natively. Example: `Calendar` hierarchy (Year → Quarter → Month → Date).

### Ragged hierarchy (variable depth)
Use PATH() functions for parent-child. Covered in `## 7. Parent-Child Hierarchies` in this file.

### Hierarchy in reports (PBIRS live connection)
Users can drill through hierarchies in matrix/table visuals. Hierarchy must be defined in the SSAS model — cannot be defined in Power BI Desktop with live connection.

### Review checklist
| Check | Severity |
|---|---|
| Balanced hierarchies defined on dimension tables (not in report) | 🟡 MEDIUM |
| Hierarchy member names are unique within level | 🟠 HIGH |
| Ragged hierarchies use PATH() pattern (not fixed-depth) | 🟡 MEDIUM |

---

## See Also

- `sqlbi-dax-patterns.md` — Core essential patterns (referenced for every project)
- `sqlbi-dax-patterns-niche.md` — Low-likelihood patterns (currency conversion, survey)
- `dax-style-guide.md` — Org DAX coding standard
