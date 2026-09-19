<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# SQLBI DAX Patterns — Core (Essential & High Likelihood)

Patterns used in most or all projects. The agent references this file for every DAX review (Mode D) and every DAX build (Mode L).

> **Upstream-First (Roche's Maxim):** Before implementing any pattern below, ask whether the transformation belongs upstream in SQL. A well-designed dimension with a pre-computed `ABC Category` column eliminates ABC DAX entirely. A `Snapshots.ActiveEventsDaily` fact table turns Events in Progress into `COUNTROWS()`. The ideal DAX measure is `SUM` / `COUNTROWS` / `DIVIDE`. Complex DAX is a last resort — document the reason in the measure `Description` when it cannot be avoided.

---

## 1. Time Intelligence Patterns

### Model Prerequisites
For all time intelligence patterns to work correctly, the following must be true in the SSAS Tabular model:

| Requirement | Detail |
|---|---|
| Date table marked | `Calendar` table → Properties → *Mark as Date Table* → `[Date Key]` column |
| Contiguous date range | No gaps between `MIN([Date Key])` and `MAX([Date Key])` — sentinels `1753-01-01` / `9999-12-31` must be filtered out by the SSAS view (`SSAS.v_Calendar`) |
| Single active relationship | Each fact date FK has exactly **one** active relationship to `'Calendar'[Date Key]`; additional date FKs use inactive relationships + `USERELATIONSHIP()` |
| DATE data type | `[Date Key]` is `DATE` in SQL and `DateTime` in SSAS — not INT, not VARCHAR |
| Fiscal year end | Org fiscal year ends **Mar 31** (Apr 1 → Mar 31); use `"03-31"` in `DATESYTD()` |

```dax
Sales YTD        := CALCULATE( [Total Sales], DATESYTD( 'Calendar'[Date Key] ) )
Sales MTD        := CALCULATE( [Total Sales], DATESMTD( 'Calendar'[Date Key] ) )
Sales QTD        := CALCULATE( [Total Sales], DATESQTD( 'Calendar'[Date Key] ) )
Sales SPLY       := CALCULATE( [Total Sales], SAMEPERIODLASTYEAR( 'Calendar'[Date Key] ) )
Sales Prior Month := CALCULATE( [Total Sales], DATEADD( 'Calendar'[Date Key], -1, MONTH ) )
Sales FYTD       := CALCULATE( [Total Sales], DATESYTD( 'Calendar'[Date Key], "03-31" ) ) -- fiscal year-end Mar 31 (Apr–Mar)

-- Rolling 12 months
Sales R12M :=
CALCULATE( [Total Sales], DATESINPERIOD( 'Calendar'[Date Key], LASTDATE( 'Calendar'[Date Key] ), -12, MONTH ) )

-- YoY % Growth
Sales YoY % :=
VAR Curr = [Total Sales]
VAR Prev = [Sales SPLY]
RETURN DIVIDE( Curr - Prev, Prev )

-- Suppress blank future periods
Sales YTD (No Future) := IF( ISBLANK( [Total Sales] ), BLANK(), [Sales YTD] )
```

---

## 2. Semi-Additive Measures

Use `LASTNONBLANK`/`FIRSTNONBLANK` for balances that must not be summed across time.

```dax
Closing Balance :=
CALCULATE( SUM( Balance[Balance] ),
    LASTNONBLANK( 'Calendar'[Date Key], CALCULATE( SUM( Balance[Balance] ) ) ) )

Opening Balance :=
CALCULATE( SUM( Balance[Balance] ),
    FIRSTNONBLANK( 'Calendar'[Date Key], CALCULATE( SUM( Balance[Balance] ) ) ) )

Avg Daily Balance :=
AVERAGEX( VALUES( 'Calendar'[Date Key] ), CALCULATE( SUM( Balance[Balance] ) ) )
```

---

## 8. USERELATIONSHIP — Role-Playing Dimensions

Only one active relationship per table pair. Activate inactive relationships inside CALCULATE.

**Model:** `Sales[OrderDateKey] → 'Calendar'[Date Key]` **(ACTIVE)**; ShipDateKey, DueDateKey **(INACTIVE)**.

```dax
Sales by Ship Date :=
CALCULATE( [Total Sales], USERELATIONSHIP( Sales[ShipDateKey], 'Calendar'[Date Key] ) )

-- Combine USERELATIONSHIP with time intelligence in same CALCULATE
Sales Ship YTD :=
CALCULATE( [Total Sales],
    USERELATIONSHIP( Sales[ShipDateKey], 'Calendar'[Date Key] ),
    DATESYTD( 'Calendar'[Date Key] ) )
```

**Preferred approach (SQLBI standard):** Use `USERELATIONSHIP` with inactive relationships — one `Calendar` table with multiple inactive FK columns pointing to it (`ShipDateKey`, `DueDateKey`, etc.). This is simpler, avoids duplicate Calendar data, and keeps time intelligence on a single marked Date Table.

**Pitfalls:** `USERELATIONSHIP` deactivates the active relationship for the CALCULATE scope. Set cross-filter to **Single** on inactive relationships — bidirectional + USERELATIONSHIP causes unexpected results on-prem.

---

## 9. ALLSELECTED Behaviour in Live Connection

| Function | Clears | Live Connection |
|---|---|---|
| `ALL( Table/Column )` | All filters | ✅ Consistent |
| `ALLSELECTED( Column )` | Inner; preserves slicer/page | ⚠️ Varies by visual type |
| `ALLEXCEPT( Table, Col )` | All except named | ✅ Consistent |

**Key behaviours (PBIRS live connection):**
- Outer context = slicer + page filters — ALLSELECTED respects these correctly.
- Matrix sub-selects can produce a different ALLSELECTED scope than card visuals — always test ranking measures in matrix.
- Avoid `ALLSELECTED( Table )` on tables with many inactive relationships — FE overhead on-prem.

```dax
-- % of total within slicer selection
Sales % of Total :=
DIVIDE( [Total Sales], CALCULATE( [Total Sales], ALLSELECTED( DimProduct[Category] ) ) )

-- Ranking within sliced set
Product Rank (Sliced) :=
RANKX( ALLSELECTED( DimProduct[ProductName] ), [Total Sales],, DESC, DENSE )
```

**When to use:** `ALLSELECTED( Column )` — visual-relative % (slicers restrict denominator). `ALL( Column )` — absolute % of grand total. `ALLEXCEPT` — preserve specific filters, remove all others.

---

## 9b. Filter-Removal Cheat Sheet

Quick reference: which function to use when you need to remove or modify filters in DAX.

| Function | What it clears | Retains slicer/page context | Use case |
|---|---|---|---|
| `ALL( 'Table' )` | All filters on the whole table | ❌ | Grand total denominators; absolute % of total |
| `ALL( 'Table'[Column] )` | Filters on one column only | ❌ | % within category (clear product filter, keep date filter) |
| `ALLEXCEPT( 'Table', Col1, Col2 )` | All filters on the table *except* named columns | ❌ | Running totals with a preserved dimension |
| `ALLSELECTED( 'Table' )` | Inner filters (removes row/col context) | ✅ | Visual-relative totals; % within slicer selection |
| `ALLSELECTED( 'Table'[Column] )` | Inner filter on one column | ✅ | Column-level % within current visual scope |
| `REMOVEFILTERS( 'Table' )` | Same as `ALL( 'Table' )` — aliases `ALL` | ❌ | Modern syntax; prefer in new measures for readability |
| `REMOVEFILTERS( 'Table'[Column] )` | Same as `ALL( 'Table'[Column] )` | ❌ | Modern syntax; same as `ALL` on a column |
| `KEEPFILTERS( expr )` | Adds filter without removing existing | n/a (additive) | Intersect new filter with existing context; prevents filter overwrite in `CALCULATE` |
| `CALCULATE( …, filter )` | Adds/replaces filter on columns in filter expression | Depends | Default `CALCULATE` modifier — replaces existing column filters |
| `CALCULATETABLE( …, filter )` | Same as CALCULATE but returns a table | Depends | Use for filtered table results, not scalar measures |

> **Decision rule (SQLBI):**
> 1. Need absolute %-of-total? → `ALL( Column )`
> 2. Need %-within-slicer-selection? → `ALLSELECTED( Column )`
> 3. Need to preserve some filters, remove others? → `ALLEXCEPT( Table, keepCol )`
> 4. Want additive filtering (intersection)? → `KEEPFILTERS()`
> 5. Need running total over a Date column? → `FILTER( ALL( 'Calendar'[Date Key] ), 'Calendar'[Date Key] <= MAX( 'Calendar'[Date Key] ) )` — see the **Cumulative Total** pattern later in this file. **Do not use `ALLEXCEPT( Table, DateColumn )` for running totals** — it removes the wrong filters and produces incorrect cumulative values when other dimensions are present.



`VAR` evaluates once and caches the result for the measure instance. Inline subexpressions may be evaluated multiple times (multiple SE queries).

```dax
-- ❌ SUM(Revenue) evaluated twice — two SE queries
Gross Margin % (Slow) := DIVIDE( SUM( Sales[Revenue] ) - SUM( Sales[Cost] ), SUM( Sales[Revenue] ) )

-- ✅ VAR — single SE query each
Gross Margin % :=
VAR Revenue = SUM( Sales[Revenue] )
VAR Cost    = SUM( Sales[Cost] )
RETURN DIVIDE( Revenue - Cost, Revenue )

-- Context save pattern: VAR captures filter context at declaration point
Sales YoY% :=
VAR Curr = [Total Sales]
VAR Prev = CALCULATE( [Total Sales], SAMEPERIODLASTYEAR( 'Calendar'[Date Key] ) )
RETURN DIVIDE( Curr - Prev, Prev )

-- Conditional with VAR (avoids double evaluation)
Conditional Growth :=
VAR Sales   = [Total Sales]
VAR PYSales = CALCULATE( [Total Sales], SAMEPERIODLASTYEAR( 'Calendar'[Date Key] ) )
VAR Growth  = DIVIDE( Sales - PYSales, PYSales )
RETURN IF( ISBLANK( PYSales ), BLANK(), IF( PYSales = 0, BLANK(), Growth ) )
```

**Rules:**
1. Use VAR for any subexpression referenced more than once.
2. VAR captures context at declaration — compute inside CALCULATE if you need a modified context value in the VAR.
3. Keep table VARs (`VAR T = SUMMARIZE(...)`) as filtered as possible — large table VARs consume VertiPaq memory.
4. VARs are scoped to the measure evaluation instance — no cross-query caching.

---

## 12. Dynamic Security with Active Directory Groups

**Always use `USERNAME()`** (returns `DOMAIN\username`). `USERPRINCIPALNAME()` is unreliable on-prem SSAS — designed for Azure AS.

```dax
-- Option A: User table (DimUserSecurity: UserName, RegionKey)
-- Role filter on DimRegion:
DimRegion[RegionKey] = LOOKUPVALUE(
    DimUserSecurity[RegionKey], DimUserSecurity[UserName], USERNAME() )

-- Option B: AD Group bridge (DimUserGroup: UserName, GroupName; refreshed from AD nightly)
[RegionKey] IN
    CALCULATETABLE(
        VALUES( DimSecurityGroup[RegionKey] ),
        TREATAS(
            CALCULATETABLE( VALUES( DimUserGroup[GroupName] ), DimUserGroup[UserName] = USERNAME() ),
            DimSecurityGroup[GroupName]
        )
    )

-- Universal filter (SecurityPermission: Principal, EntityKey, EntityType)
DimBranch[BranchKey] IN
    CALCULATETABLE( VALUES( SecurityPermission[EntityKey] ),
        SecurityPermission[Principal] = USERNAME(),
        SecurityPermission[EntityType] = "Branch" )
```

**AD group bridge refresh:** SSIS/SQL Agent job querying AD via `System.DirectoryServices.DirectorySearcher` or linked server. Refresh nightly.

**Test RLS:** In DAX Studio, use Roles connection option. In SSMS: `EXECUTE AS USER = 'DOMAIN\testuser'`.

---

## 16. Measure Quality Checklist

- [ ] `DIVIDE()` — not `/` — for all divisions
- [ ] Returns `BLANK()` (not 0) when no data
- [ ] Tested in matrix visual with row/column/page/slicer filters active
- [ ] Tested at grand total (no filters)
- [ ] `VAR` for any subexpression used more than once
- [ ] No `FILTER( AllTable, [Measure] > x )` — column filter or KEEPFILTERS instead
- [ ] Format string set explicitly (not "Auto")
- [ ] Description populated in measure properties
- [ ] Assigned to Display Folder
- [ ] Server Timings checked in DAX Studio — FE time not dominant
- [ ] RLS-sensitive measures tested with impersonation in DAX Studio
- [ ] Time intelligence tested at year / quarter / month / day grain

---

## 17. DAX Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| `SUM(Col) / SUM(Col2)` | Division by zero error | `DIVIDE()` |
| `FILTER( Table, [Measure] > x )` | FE per row (CallbackDataID) | Filter on column, not measure |
| `CALCULATE( X, ALL( Table ) )` in iterator | Removes all filters globally | `REMOVEFILTERS()` with scope or `ALLEXCEPT` |
| `COUNTROWS( FILTER( Table, cond ) )` | Iterates full table in FE | `CALCULATE( COUNTROWS(Table), cond )` |
| `IF( SUM() = 0, BLANK(), ... )` | `SUM()` returns BLANK not 0 when no rows | `IF( ISBLANK( [Measure] ), BLANK(), ... )` |
| `RELATED()` inside measure | Only valid in row context | `LOOKUPVALUE()` or TREATAS |
| Calculated columns for derivable values | Materialised in VertiPaq; wastes memory | Use measures; calc cols only for grouping/slicing |
| Unused columns imported | Bloats memory; slows processing | Remove or exclude from partition query |
| `FORMAT()` inside measure body | Returns text; breaks numeric aggregations | Use Format String property instead |

---

## 18. Measure Organisation Conventions

### Display Folder Structure
```
📁 [Key Metrics]       Total Sales, Total Cost, Gross Profit, Gross Margin %
📁 [Time Intelligence] Sales YTD, MTD, SPLY, YoY %, R12M
📁 [Ratios & Rates]    Avg Transaction Value, Conversion Rate, Return Rate %
📁 [Inventory]         Closing Stock, Opening Stock, Stock Turns
📁 [_Debug]            _Debug Row Count, _Debug Context Test  ← hidden; devs only
```

### Naming Conventions
- Base measures: `Total Sales`, `Units Sold` — plain Title Case
- Time intelligence: `Sales YTD`, `Sales SPLY`, `Sales YoY %` — suffix variant
- Helper/debug: `_Sales Base`, `_Has Filter` — underscore prefix
- No abbreviations in public names; no `FORMAT()` in bodies

### Description (every production measure)
`"Sum of Sales[SalesAmount]. Includes all channels. Excludes cancelled orders (OrderStatus='Cancelled' filtered at partition). Last reviewed: YYYY-MM-DD by [Author]."`

---

## Events in Progress

**Source:** https://www.daxpatterns.com/events-in-progress/
**Likelihood:** 🔴 Essential — project start/end dates, leave periods, active cases, open tickets

The Events in Progress pattern counts entities that are active (in progress) on a given date — i.e. their start date is on or before the report date AND their end date is on or after the report date (or NULL = still open).

### Data model requirements
- Fact or snapshot table with `StartDateKey` and `EndDateKey` (both FK to `Calendar`)
- `EndDateKey` = `DATE(9999,12,31)` (sentinel) if the event is still open
- Both relationships to `Calendar` — only one can be active; use `USERELATIONSHIP()` for the inactive one

### Pattern
```dax
Events In Progress =
VAR SelectedDateKey = MAX( 'Calendar'[Date Key] )   -- DATE type date key from current filter context
RETURN
CALCULATE(
    COUNTROWS( 'Fact Active Events' ),   -- replace with your fact/snapshot table name
    FILTER(
        ALL( 'Fact Active Events' ),
        'Fact Active Events'[Start Date Key] <= SelectedDateKey
        && (
            'Fact Active Events'[End Date Key] = DATE(9999, 12, 31)   -- DATE(9999,12,31) = still open (sentinel convention)
            || 'Fact Active Events'[End Date Key] >= SelectedDateKey
        )
    )
)
```

**Performance note:** This pattern requires a `FILTER(ALL(...))` — it is one of the legitimate exceptions to the FILTER(ALL) anti-pattern rule because there is no other way to compare two date keys from the same Calendar table. Document the exception in the measure description.

**Org-specific note:** For PBIRS live connection, this measure may be slow on large fact tables. Consider adding a pre-computed `Snapshots.ActiveEventsDaily` periodic snapshot as an alternative data source.

---

## Budget — Allocation at Different Grain

**Source:** https://www.daxpatterns.com/budget/
**Likelihood:** 🔴 Essential — actuals vs budget is a near-universal BI requirement

Budget data is typically stored at a higher grain than actuals (e.g. budget by month+department, actuals by day+employee+project). This pattern reallocates budget to match the actuals grain for comparison.

### Data model
- `Fact.Actuals` — transaction grain
- `Fact.Budget` — higher grain (e.g. month + cost centre); stores `BudgetAmount`
- Both connected to `Calendar` and shared dimensions (e.g. `CostCentre`)
- Budget fact uses `Calendar` relationship on the month-level date key (first of month, or use month number column)

### Pattern — allocate budget proportionally
```dax
Budget Amount =
CALCULATE(
    SUM( 'Fact Budget'[Budget Amount] ),
    ALL( 'Calendar'[Date] ),                    -- remove day filter
    VALUES( 'Calendar'[Year Month Number] )     -- keep month filter
)

Budget Variance =
[Total Actuals Amount] - [Budget Amount]

Budget Variance % =
DIVIDE(
    [Budget Variance],
    [Budget Amount],
    BLANK()
)
```

### Pattern — budget at lower grain than available (spreading)
If budget must be spread across days proportionally:
```dax
Budget Amount Spread =
VAR DaysInMonth =
    CALCULATE(
        COUNTROWS( 'Calendar' ),
        ALL( 'Calendar'[Date] ),
        VALUES( 'Calendar'[Year Month Number] )
    )
VAR DaysSelected = COUNTROWS( 'Calendar' )
RETURN
DIVIDE(
    CALCULATE(
        SUM( 'Fact Budget'[Budget Amount] ),
        ALL( 'Calendar'[Date] ),
        VALUES( 'Calendar'[Year Month Number] )
    ) * DaysSelected,
    DaysInMonth,
    BLANK()
)
```

---

## New and Returning Entities (Customers / Projects / Clients)

**Source:** https://www.daxpatterns.com/new-and-returning-customers/
**Likelihood:** 🟠 High — client/project acquisition, churn, and recovery reporting

Classifies entities (customers, projects, clients) as: New, Returning, Lost, or Recovered in a period.

### Definitions
- **New**: first activity ever is within the selected period
- **Returning**: had activity before AND within the selected period
- **Lost**: had activity before the selected period but NOT in the selected period
- **Recovered**: had no activity in the previous period but has activity now (and is not New)

### Pattern
```dax
-- Helper: first activity date key per entity
-- Best implemented as a calculated column on the dimension:
-- 'Customer'[First Activity Date Key] = MINX(RELATEDTABLE('Fact Sales Transaction'), 'Fact Sales Transaction'[Date Key])

New Entities =
VAR MinDateKeyInPeriod = MIN( 'Calendar'[Date Key] )   -- DATE type date key
RETURN
CALCULATE(
    DISTINCTCOUNT( 'Fact Sales Transaction'[Customer Key] ),
    FILTER(
        VALUES( 'Customer'[Customer Key] ),
        CALCULATE( MIN( 'Fact Sales Transaction'[Date Key] ) ) >= MinDateKeyInPeriod
    )
)

Returning Entities =
CALCULATE(
    DISTINCTCOUNT( 'Fact Sales Transaction'[Customer Key] ),
    FILTER(
        VALUES( 'Customer'[Customer Key] ),
        CALCULATE( MIN( 'Fact Sales Transaction'[Date Key] ) ) < MIN( 'Calendar'[Date Key] )
    )
)
```

**Note:** Replace `Customer Key` and `Fact SalesTransaction` with the entity and fact table relevant to the report.

---

## Cumulative Total (Running Total)

**Source:** https://www.daxpatterns.com/cumulative-total/
**Likelihood:** 🟠 High — cumulative spend, running balance, cumulative project hours

### Pattern
```dax
Cumulative Sales Amount =
CALCULATE(
    [Total Sales Amount],
    FILTER(
        ALL( 'Calendar'[Date] ),
        'Calendar'[Date] <= MAX( 'Calendar'[Date] )
    )
)
```

**With reset per year:**
```dax
YTD Cumulative Sales Amount =
CALCULATE(
    [Total Sales Amount],
    FILTER(
        ALL( 'Calendar'[Date] ),
        'Calendar'[Date] <= MAX( 'Calendar'[Date] )
        && 'Calendar'[Year] = MAX( 'Calendar'[Year] )
    )
)
```

**Performance note:** `FILTER(ALL('Calendar'[Date]))` is a column-only filter — much more efficient than `FILTER(ALL('Calendar'))`. Always filter the single Date column, not the whole table.

---

## See Also — Advanced and Niche Patterns

- `sqlbi-dax-patterns-advanced.md` — Medium-likelihood situational patterns (M2M, calc groups, segmentation, etc.)
- `sqlbi-dax-patterns-niche.md` — Low-likelihood patterns (currency conversion, survey/basket analysis)
- `dax-style-guide.md` — Org DAX coding standard (mandatory for all measures)
- `dax-studio-workflow.md` — Performance profiling with DAX Studio
