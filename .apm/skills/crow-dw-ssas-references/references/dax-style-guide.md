<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

## Purpose

This guide defines the organisation DAX coding standard for SSAS Tabular models. Copilot agents must apply this standard when generating DAX measures, reviewing DAX measures, or reviewing SSAS Tabular models. Every generated measure must conform to these rules.

## Guiding Design Philosophy — Upstream-First (Roche's Maxim)

> **"Data should be transformed as far upstream as possible, and as far downstream as necessary."**

This is the single most important principle governing DAX authorship in this organisation:

- **Simple DAX is good DAX.** The best measure is `SUM`, `COUNTROWS`, or `DIVIDE`. If you reach for `FILTER(ALL(...))` or nested `CALCULATE`, first ask whether the model shape is wrong.
- **Complex calculations belong in SQL first.** If a measure is computing something that could be a column in the DW load SP or an SSAS calculated column, push it upstream.
- **Upstream preference order:** Staging SP → Dimension/Fact load SP → DW computed column → SSAS calculated column → DAX measure.
- **Document exceptions.** When complex DAX is genuinely necessary (e.g., ad-hoc time window that cannot be pre-computed), document the reason in the measure `Description` field.

Apply this lens during every DAX review: if a measure could be simplified by a model design change, flag it as a design issue alongside the DAX finding.

### Organisational conventions

- SSAS Tabular only.
- Reports connect to SSAS Tabular using PBIRS live connection; report import mode is not used.
- Date dimension SSAS table: `'Calendar'`.
- Date dimension warehouse table: `Dimension.Calendar`.
- Surrogate keys follow `{EntityName}Key`, are hidden in the model, and are not exposed to report users.
- Visible attributes use Title Case with spaces.
- Roles follow `{Name} Consumers` for Read access and `{Name} Authors` for Read plus Process access.
- Every measure requires `Description`, `FormatString`, and `DisplayFolder`.

## Measure naming conventions

### General naming rules

- Use Title Case for visible measures.
- Use clear business terms, for example `Total Sales Amount`, `Average Order Value`, and `Customer Count`.
- Do not use abbreviations unless they are universally understood. `YTD` is acceptable; shortened names such as `Avg Rev Per Cust` are not.
- Base measures must be descriptive noun phrases, for example `Sales Amount` and `Order Count`.
- Time intelligence variants must start with the time period, for example `YTD Sales Amount`, `Prior Year Sales Amount`, and `YoY Sales Amount Var %`.

### Hidden helper and debug measures

- Hidden helper measures must start with `_`, for example `_Sales Amount Base`.
- Debug measures must start with `_Debug`, for example `_Debug Oldest Source` and `_Debug Model Processed`.
- Debug measures must be hidden unless there is an approved operational reporting use case.

## Mandatory measure properties

### Required properties

Every measure, with no exceptions, must include the following metadata:

```text
Description: [Business description].
Valid groupings: [List dimensions this measure can be meaningfully sliced by].
Notes: [Additive, semi-additive, or non-additive; include caveats].
FormatString: [For example #,##0.00 / #,##0 / 0.00% / "General Date"]
DisplayFolder: [Business area or sub-folder, for example Sales\Time Intelligence]
```

### Complete example

```text
[Total Sales Amount]
Description: Total net sales amount after discounts and returns.
Valid groupings: Calendar, Customer, Product, Region, Sales Channel.
Notes: Fully additive. Source: Fact.SalesTransaction.Amount.
FormatString: #,##0.00
DisplayFolder: Sales
```

## Formatting and indentation

### Formatting standard

- Use DAX Formatter conventions: https://www.daxformatter.com
- Indent 4 spaces per nesting level.
- Put each function argument on its own line when a function has two or more arguments.
- Put the opening parenthesis on the same line as the function name.
- Put the closing parenthesis on its own line, aligned with the function call.

### Bad formatting example

```dax
Total Sales Amount = CALCULATE(SUM(Fact_SalesTransaction[Amount]),FILTER(ALL(Dimension_Customer),Dimension_Customer[Region]="East"))
```

### Good formatting example

```dax
Total Sales Amount =
CALCULATE(
    SUM( 'Fact SalesTransaction'[Amount] ),
    FILTER(
        ALL( 'Customer' ),
        'Customer'[Region] = "East"
    )
)
```

## VAR and RETURN pattern

### Required usage

Any measure with more than one logical step must use `VAR` and `RETURN`. Use variables to capture reusable values, improve readability, and avoid repeated evaluation.

```dax
YoY Sales Amount Var % =
VAR CurrentPeriod = [Total Sales Amount]
VAR PriorPeriod   = [Prior Year Sales Amount]
RETURN
    DIVIDE(
        CurrentPeriod - PriorPeriod,
        PriorPeriod,
        BLANK()
    )
```

## Division standard

### Always use DIVIDE

Use `DIVIDE()` for all division. Do not use the division operator in measures.

```dax
Average Order Value =
DIVIDE(
    [Total Sales Amount],
    [Order Count],
    BLANK()
)
```

## BLANK and zero handling

### No-data scenarios

- Return `BLANK()` when no data is the correct answer.
- Return `0` only when zero is a meaningful business value.
- Derived measures should propagate blanks from base measures when a blank result avoids misleading visuals.

```dax
Sales Amount Per Customer =
IF(
    ISBLANK( [Total Sales Amount] ),
    BLANK(),
    DIVIDE(
        [Total Sales Amount],
        [Customer Count],
        BLANK()
    )
)
```

## Time intelligence

### Calendar table rules

- All time intelligence must reference the `'Calendar'` SSAS table.
- The `'Calendar'` table must be marked as a Date Table in the SSAS model.
- The date column used for time intelligence is `'Calendar'[Date Key]` and must use a Date data type.
- Confirm the organisational calendar grain and fiscal calendar requirements before creating fiscal calculations.

### Standard time intelligence patterns

```dax
YTD Sales Amount =
CALCULATE(
    [Total Sales Amount],
    DATESYTD( 'Calendar'[Date Key] )
)
```

```dax
-- Fiscal year YTD (Apr 1 – Mar 31, org standard)
-- FY2024 = Apr 1 2024 – Mar 31 2025; use fiscal year-end month/day "03-31"
FYTD Sales Amount =
CALCULATE(
    [Total Sales Amount],
    DATESYTD( 'Calendar'[Date Key], "03-31" )
)
```

```dax
Prior Year Sales Amount =
CALCULATE(
    [Total Sales Amount],
    SAMEPERIODLASTYEAR( 'Calendar'[Date Key] )
)
```

```dax
YoY Sales Amount Var % =
DIVIDE(
    [Total Sales Amount] - [Prior Year Sales Amount],
    [Prior Year Sales Amount],
    BLANK()
)
```

### Date range boundary convention

The org standard for date range semantics is **inclusive on both ends from the user's perspective**: when a user selects "January 1 to January 31", all data on January 31 is included.

**In DAX** — this maps directly to `DATESBETWEEN` semantics (both ends inclusive). Since `[Date Key]` is `DATE` type (no time component), `DATESBETWEEN` is safe:

```dax
-- Correct: inclusive both ends on a DATE column
January Sales =
CALCULATE(
    [Total Sales Amount],
    DATESBETWEEN( 'Calendar'[Date Key], DATE(2024,1,1), DATE(2024,1,31) )
)
```

Standard time intelligence functions (`DATESYTD`, `DATESMTD`, `DATESQTD`, `SAMEPERIODLASTYEAR`) manage their own boundaries automatically — do not wrap them in additional `DATESBETWEEN` calls.

**In SQL (ELT load SPs and queries against the DW)** — implement the user-facing inclusive contract using a **half-open interval** to avoid time-of-day issues on `DATETIME` source columns (even though the DW `[Date Key]` is `DATE`, source systems may use `DATETIME`):

```sql
-- ✅ Half-open interval — preferred in ELT SQL
WHERE [OrderDateKey] >= '2024-01-01' AND [OrderDateKey] < '2024-02-01'

-- ❌ BETWEEN on a DATETIME source column — avoid (misses 23:59:59 on the last day)
WHERE [OrderDate] BETWEEN '2024-01-01' AND '2024-01-31'
```

> **If no org standard exists for a project**: record the decision in the project spec and adopt **inclusive-inclusive** as the user-facing contract with half-open implementation in SQL. This is the Power BI slicer default and requires no special end-user documentation.

| Anti-pattern | Why forbidden | Correct alternative |
|---|---|---|
| `BETWEEN` on DATETIME columns in ELT | Misses rows at 23:59:59 on the last day | Use `>= start AND < next_period_start` |
| `DATESBETWEEN` on non-DATE column | Unreliable boundary matching on DATETIME | Convert to DATE or use Calendar column |
| Hardcoded end-exclusive boundaries without documentation | Silently drops last-day data; confuses reviewers | Document convention in measure Description |



### Forbidden patterns

| Anti-pattern | Why forbidden | Correct alternative |
|---|---|---|
| Division operator with a denominator measure | Divide-by-zero or misleading error behavior | Use `DIVIDE()` |
| `FILTER(ALL(Table), condition)` | As a default filter modifier, scans the entire table and can severely reduce performance | Use `KEEPFILTERS()` or `CALCULATETABLE()` for user-selection filters. **Exception:** `FILTER(ALL(...))` is the correct SQLBI pattern for Events in Progress and cumulative total/running totals that must ignore the current filter context — document the reason in the measure `Description` |
| `EARLIER()` in measures | It is not appropriate for measure evaluation patterns | Use `VAR` to capture context |
| Implicit auto-measures | Required description, folder, and format metadata cannot be controlled | Always create explicit measures |
| `COUNTROWS(FILTER(...))` | Can force unnecessary table scans | Use `CALCULATE(COUNTROWS(...), condition)` |
| Hardcoded dates | Breaks across fiscal years and calendar changes | Use `'Calendar'` relative period columns |
| `TODAY()` or `NOW()` in cached measures | Cached results can appear stale after processing | Use a `'Calendar'[Is Today]` flag or a data freshness pattern |
| Referencing any date table other than `'Calendar'` | Date relationships and standard time intelligence may not work correctly | Always use `'Calendar'` |
| `USERPRINCIPALNAME()` in RLS | Unreliable on-premises with Kerberos delegation | Use `USERNAME()` which returns `DOMAIN\username` |
| Bidirectional many-to-many without bridge table | Explosive filter expansion, ambiguous row context | Use bridge table + `TREATAS` |

---

## Filter-Context Functions — Style Guide

### ALL / ALLEXCEPT / ALLSELECTED / REMOVEFILTERS

Use these functions deliberately. The wrong choice produces silently incorrect totals.

```dax
-- ALL(Table) — removes ALL filters on the table; absolute denominator
Sales % Grand Total :=
DIVIDE( [Total Sales], CALCULATE( [Total Sales], ALL( 'Fact Sales' ) ) )

-- ALL(Column) — removes filter on one column only
Sales % of Category :=
DIVIDE( [Total Sales], CALCULATE( [Total Sales], ALL( 'Dimension Product'[Product Name] ) ) )

-- ALLEXCEPT — remove all filters on a table except specified columns
Running Total Sales :=
CALCULATE( [Total Sales],
    ALLEXCEPT( 'Calendar', 'Calendar'[Year] ),
    'Calendar'[Date Key] <= MAX( 'Calendar'[Date Key] ) )

-- ALLSELECTED — preserve outer (slicer/page) context; relative to visual selection
Sales % of Slicer Selection :=
DIVIDE( [Total Sales], CALCULATE( [Total Sales], ALLSELECTED( 'Dimension Product'[Category] ) ) )

-- REMOVEFILTERS — modern alias for ALL; prefer in new measures for readability
Sales vs Budget :=
DIVIDE( [Total Sales], CALCULATE( [Total Budget], REMOVEFILTERS( 'Calendar'[Month] ) ) )
```

**Decision rule:** 
- Need % of absolute grand total? → `ALL( Column )`
- Need % within the current slicer selection? → `ALLSELECTED( Column )`  
- Need running total or cumulative, ignoring row context for one dimension? → `ALLEXCEPT( Table, DateColumn )`
- New measure (no legacy constraints)? → `REMOVEFILTERS()` over `ALL()` for clarity

### KEEPFILTERS

Use `KEEPFILTERS()` inside `CALCULATE` when you want the new filter to **intersect** with the existing filter context rather than replace it:

```dax
-- Without KEEPFILTERS: filter context for Category is REPLACED with "Clothing"
-- → shows Clothing total even if user has selected a different category in a slicer
Clothing Sales :=
CALCULATE( [Total Sales], 'Dimension Product'[Category] = "Clothing" )

-- With KEEPFILTERS: filter context is INTERSECTED
-- → returns BLANK if user's slicer selection doesn't include "Clothing"
Clothing Sales (Filtered) :=
CALCULATE( [Total Sales], KEEPFILTERS( 'Dimension Product'[Category] = "Clothing" ) )
```

### TREATAS

Use `TREATAS` to virtually relate two tables **without adding a physical relationship** to the model. Essential for security patterns, M2M bridge patterns, and What-If parameters.

```dax
-- Apply a filter from a disconnected table to a related dimension
Sales in Selected Region :=
CALCULATE( [Total Sales],
    TREATAS(
        VALUES( 'DimScenarioRegion'[Region Code] ),
        'Dimension Region'[Region Code]
    )
)

-- Dynamic RLS alternative using TREATAS (SQLBI preferred for security tables)
-- Role table filter expression on 'Dimension Region':
COUNTROWS(
    TREATAS(
        CALCULATETABLE(
            VALUES( 'Security User Permissions'[Permitted Value] ),
            'Security User Permissions'[User Name] = USERNAME()
        ),
        'Dimension Region'[Region Code]
    )
) > 0
```

**When to use TREATAS vs relationship:**
- `TREATAS`: disconnected tables, security patterns, M2M without physical relationship, parameter tables
- Physical relationship: standard fact-to-dimension, role-playing date FKs (use `USERELATIONSHIP`)



## Display folder conventions

### Folder rules

- Top-level folders must be business area names matching the report domain, for example `Sales`, `Projects`, `Finance`, and `HR`.
- Use sub-folders for variants, for example `Sales\Time Intelligence` and `Sales\Ratios`.
- Debug measures must use the `_Debug` folder.
- Hidden helper measures may be placed in any relevant folder, but must still have a folder for maintainability.
- Never leave measures in the root. Always assign a `DisplayFolder`.

---

## Performance rules

### Iterator avoidance

Iterators (`SUMX`, `AVERAGEX`, `MAXX`, `MINX`, `COUNTX`, `RANKX`) evaluate a row-by-row expression. On large tables they become the dominant query cost.

| Rule | Threshold | Action |
|---|---|---|
| Avoid iterators on large fact tables | > 5M rows | Pre-compute in DW load SP or SSAS calculated column |
| Avoid nested CALCULATE inside iterators | Any table size | Extract to VAR outside the iterator |
| Prefer SUM/COUNT over SUMX/COUNTX | When expression is a single column | `SUM(Table[Column])` is always faster than `SUMX(Table, Table[Column])` |

**Justified iterator use** (document reason in `Description`):
- Row-level multiplication: `SUMX(Sales, Sales[Qty] * Sales[UnitPrice])` — cannot be pre-aggregated
- Events in Progress: `COUNTROWS(FILTER(ALL(...)))` — cumulative pattern
- Weighted averages: `DIVIDE(SUMX(...), SUM(...))` — requires row context

### Context transition minimisation

A context transition occurs when CALCULATE (or a measure reference) appears inside a row context. Each transition recalculates for every row.

```dax
-- ❌ BAD: Context transition inside iterator (N evaluations of [Tax Rate Measure])
Sales with Tax =
SUMX( Sales, Sales[Amount] * (1 + [Tax Rate Measure]) )

-- ✅ GOOD: Resolve outside iterator
Sales with Tax =
VAR _TaxRate = [Tax Rate Measure]
RETURN SUMX( Sales, Sales[Amount] * (1 + _TaxRate) )
```

**Rule**: Never reference a measure inside `SUMX`/`FILTER`/`ADDCOLUMNS` unless the measure must vary per row. If it must, document why.

### VAR caching

Any sub-expression used more than once must be assigned to a VAR:

```dax
-- ❌ BAD: Same sub-expression evaluated twice
YoY % =
DIVIDE(
    [Total Sales] - CALCULATE([Total Sales], SAMEPERIODLASTYEAR('Calendar'[Date Key])),
    CALCULATE([Total Sales], SAMEPERIODLASTYEAR('Calendar'[Date Key]))
)

-- ✅ GOOD: Evaluated once, referenced twice
YoY % =
VAR _Current = [Total Sales]
VAR _PY = CALCULATE([Total Sales], SAMEPERIODLASTYEAR('Calendar'[Date Key]))
RETURN DIVIDE(_Current - _PY, ABS(_PY))
```

### DISTINCTCOUNT on high cardinality

`DISTINCTCOUNT` on columns with > 1M distinct values is expensive. Alternatives:
- Pre-aggregate distinct counts in DW load (daily/monthly grain)
- Use approximate: `APPROXIMATE DISTINCTCOUNT` (Power BI Service only — not available in SSAS on-prem)
- Reduce granularity: count at month level instead of day

### Calculation group benefits

Calculation groups reduce measure proliferation and improve maintainability and consistency. Performance is comparable to hand-written equivalents — `SELECTEDMEASURE()` still evaluates the full measure in context. Their value is governance, not speed:
- > 5 base measures × > 3 time-intelligence variants → single source of truth for time logic
- One fix applies to all measures (consistency guarantee)
- Reduced model clutter and easier discoverability

**Rule**: Prefer Calculation Groups for maintainability when measure variants proliferate. Benchmark with DAX Studio if performance is a concern — they are not inherently faster.

### Agent review: performance flags

| Pattern found | Severity | Recommendation |
|---|---|---|
| `SUMX` / `COUNTX` on table > 5M rows | 🟠 HIGH | Consider upstream pre-computation |
| Measure reference inside `SUMX` / `FILTER` / `ADDCOLUMNS` | 🟠 HIGH | Extract to VAR if constant across rows |
| Same sub-expression repeated without VAR | 🟡 MEDIUM | Assign to VAR |
| `DISTINCTCOUNT` on column > 1M distinct | 🟡 MEDIUM | Pre-aggregate at load time (APPROXIMATEDISTINCTCOUNT unavailable on-prem) |
| > 15 time-intelligence measure copies without Calculation Group | 🟡 MEDIUM | Convert to Calculation Group (maintainability) |
| `FILTER(ALL(FactTable), condition)` without documented exception | 🟠 HIGH | Filter on dimension column directly in CALCULATE |

## PBIRS live-connection constraints

### Report authoring constraints

Because reports connect to SSAS Tabular using live connection, these constraints apply:

- Do not create report-level measures.
- Do not use composite model features.
- Do not use the Q&A visual.
- All calculated columns must be created in the SSAS model, not in the report.
- Field parameters are not supported for this reporting pattern.
- Users see exactly what the SSAS model exposes; hide columns and measures that should not be visible.

## Review checklist

### Mode D DAX measure review

When reviewing a DAX measure, check all of the following:

| Check | Severity if failed |
|---|---|
| Uses `DIVIDE()` for division | 🔴 CRITICAL |
| Has `Description` with valid groupings and notes | 🟠 HIGH |
| Has `FormatString` | 🟠 HIGH |
| Has `DisplayFolder` | 🟡 MEDIUM |
| Uses `VAR` and `RETURN` for multi-step logic | 🟡 MEDIUM |
| References `'Calendar'` for time intelligence | 🔴 CRITICAL |
| Avoids `FILTER(ALL())` as a default filter modifier (exception: Events in Progress, cumulative totals) | 🟠 HIGH |
| Avoids `EARLIER()` in measures | 🟠 HIGH |
| Avoids implicit auto-measures | 🟡 MEDIUM |

### Review outcome expectations

- Flag critical issues before style issues.
- Require remediation for missing metadata.
- Prefer explicit, readable measures over clever compact expressions.
- Confirm the measure can be meaningfully sliced by the stated valid groupings.
- Confirm hidden helper and debug measures are hidden and correctly named.
