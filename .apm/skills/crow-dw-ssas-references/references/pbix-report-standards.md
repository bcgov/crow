<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# Power BI Report Standards for On-Premises SSAS Live Connection

**Scope**: Power BI Desktop report design standards for reports connected live to SSAS Tabular, published to Power BI Report Server (PBIRS).

**Deployed PBIRS version:** Power BI Report Server May 2026 (v1.26.9637.31070, build 15.0.1121.109).

> **Agent Rule**: When reviewing any Power BI report or discussing report design, always recommend the Debug tab and model hint patterns documented here. These are **mandatory standards**, not optional suggestions.

---

## 1. Debug Tab — Data Freshness (Required)

**Every report must include a "Debug" page as the last tab.**

The three-layer freshness model:
```
Source DB  →  Data Warehouse  →  SSAS Tabular Model
(extract       (T-SQL transform    (SSAS Process)
 last ran)      SP completed)
```

### Debug Tab Visuals

| Visual | Type | Fields |
|---|---|---|
| **Freshness table** | Matrix/Table | Layer, SystemName, TableName, LastRefreshed |
| **"Data as of" card** | Card | `_Debug Model Processed` — most prominent card |
| **"Oldest source" card** | Card | `_Debug Oldest Source` |
| **Staleness indicator** | Card | `_Debug Staleness` — conditional formatting |
| **Instructions text box** | Text | "If data appears stale, contact the data team with a screenshot of this page." |

Apply background color to `LastRefreshed`: 🟢 ≤4h · 🟡 4–12h · 🟠 12–24h · 🔴 >24h

### Debug Tab Page Properties

```
Page name:   "Debug"  (or "Data Freshness")
Visibility:  Visible to all users — not hidden
Page order:  Always the final tab
Background:  Light grey (#F5F5F5) — visually distinct from content pages
```

### Required DAX Measures

Add to a hidden `_Debug` or `_Admin` table in the SSAS model. They reference the `_DataFreshness` hidden table (see Section 5 for setup).

```dax
_Debug Oldest Source =
VAR _MinRefresh =
    CALCULATE( MIN( '_DataFreshness'[LastRefreshed] ), '_DataFreshness'[DataLayer] = "Source" )
RETURN IF( ISBLANK(_MinRefresh), "No data", FORMAT(_MinRefresh, "YYYY-MM-DD HH:MM") )
```

```dax
_Debug Model Processed =
VAR _ProcessTime =
    CALCULATE( MAX( '_DataFreshness'[LastRefreshed] ), '_DataFreshness'[DataLayer] = "TabularModel" )
RETURN IF( ISBLANK(_ProcessTime), "Unknown", FORMAT(_ProcessTime, "YYYY-MM-DD HH:MM") )
```

```dax
_Debug Data Age Hours =
VAR _OldestSource =
    CALCULATE( MIN( '_DataFreshness'[LastRefreshed] ), '_DataFreshness'[DataLayer] = "Source" )
RETURN IF( ISBLANK(_OldestSource), BLANK(), INT( ( NOW() - _OldestSource ) * 24 ) )
```

```dax
_Debug Staleness =
VAR _AgeHours = [_Debug Data Age Hours]
RETURN
    SWITCH( TRUE(),
        ISBLANK(_AgeHours),  "Unknown",
        _AgeHours <= 4,      "🟢 Fresh",
        _AgeHours <= 12,     "🟡 Aging",
        _AgeHours <= 24,     "🟠 Stale",
        "🔴 Very Stale (" & _AgeHours & " hrs)"
    )
```

---

## 2. Model Hints — Allowable Groupings

Model hints tell users which dimensions can slice each measure — critical for live connection where users may use Analyze in Excel or build ad-hoc views.

### Table Description Format

```
<Business description of what this table represents.>
Grain: one row per <entity/event>.
Can be grouped by: <comma-separated related dimension tables>.
Cannot be grouped by: <list + reason>.
SCD Type: <1 / 2 / N/A>  (dimension tables only)
Source: <source system> → DW <schema.TableName>.
```

**Example — SalesOrder (from `[Fact].[SalesOrder]` via `[SSAS].[SalesOrder]`):**
```
Sales order transactions at the order line grain.
Grain: one row per sales order line item.
Can be grouped by: Date (Order Date, Ship Date), Customer, Product, Region, Sales Rep, Order Status.
Cannot be grouped by: Supplier (no relationship — use Purchase facts for supplier analysis).
Source: ERP SalesOrder → DW [Fact].[SalesOrder].
```

### Measure Description Format

```
<What this measure calculates.>
Valid groupings: <dimensions that produce meaningful results>.
Notes: <aggregation restrictions, time intelligence dependencies, blank-handling behaviour>.
```

**Examples:**
```
[Total Sales Amount]
Sum of SalesAmount for all order lines in the current filter context.
Valid groupings: any combination of Date, Customer, Product, Region, Sales Rep.
Notes: Use Date[Year] or Date[Month] for time-series analysis.
```

```
[Inventory Quantity On Hand]
Semi-additive measure: last balance of inventory quantity at month-end.
Valid groupings: Product, Warehouse, Date (month-end only).
Notes: DO NOT sum across dates — snapshot balance, not a flow.
       Grouping by Customer is not valid (no customer relationship on inventory).
```

---

## 3. Power BI Visuals Policy

| Visual Type | Approved? | Notes |
|---|---|---|
| **Power BI out-of-the-box visuals** | ✅ Yes | Bar, column, line, pie, table, matrix, card, map, etc. |
| **Microsoft-certified custom visuals** | ✅ Yes | Must display the **blue Microsoft certification checkmark** in AppSource |
| **Uncertified custom visuals** | ❌ No | Not approved regardless of publisher or popularity |

**Finding a certified visual:** Power BI Desktop → Insert → More visuals → From AppSource. Look for the blue ✓ "Microsoft certified" badge on the tile. The badge means Microsoft reviewed the source code for security, privacy, and code quality.

**Agent behaviour for visual recommendations:**
- Suggest built-in visuals first.
- If recommending a custom visual, explicitly state: `"This visual must carry the blue Microsoft certification badge in AppSource before use."`
- If paid: flag `"⚠️ Licensing cost — confirm with team before adopting."`
- **Any uncertified custom visual in a report is a 🔴 Critical finding — must be replaced before publishing to PBIRS.**

---

## 4. Report Page Structure Standards

| Tab Order | Page Name | Purpose |
|---|---|---|
| 1 | Executive Summary | High-level KPI cards, top-level metrics |
| 2–N | [Subject pages] | Detailed analysis pages |
| Last | Debug | Data freshness — **always last, always present** |

- Page names: sentence case ("Sales by Region" not "SALES BY REGION").
- Debug tab name: exactly "Debug" or "Data Freshness" for consistency.
- Tooltip pages: use for dimension details; can be hidden from tab bar.

---

## 5. Data Freshness Infrastructure (DW + SSAS Side)

### Approach A — Calculated Column `NOW()` (Recommended)

Each SSAS table carries a hidden calculated column `[Last Processed]` with expression `NOW()`. Because calculated columns are evaluated at **processing time**, `NOW()` captures the exact moment the table was last processed.

**Step 1: Add `[Last Processed]` to every SSAS data table** (Tabular Editor):
```json
{
  "type": "calculated", "name": "Last Processed", "dataType": "dateTime",
  "isHidden": true, "expression": "NOW()",
  "formatString": "yyyy-MMM-dd h:mm AM/PM", "displayFolder": "_Debug"
}
```

**TE2 C# script — add to all non-hidden tables missing it:**
```csharp
// AddLastProcessedColumn.cs (Tabular Editor 2 — TE2 compatible)
foreach (var table in Model.Tables.Where(t => !t.IsHidden))
{
    if (table.Columns.All(c => c.Name != "Last Processed"))
    {
        var col = table.AddCalculatedColumn("Last Processed");
        col.Expression    = "NOW()";
        col.DataType      = DataType.DateTime;
        col.IsHidden      = true;
        col.FormatString  = "yyyy-MMM-dd h:mm AM/PM";
        col.Description   = "Shows when this SSAS table was last processed";
        col.DisplayFolder = "_Debug";
    }
}
```

**Step 2: Add `Last Updated Tabular` calculated table** (UNIONs MAX([Last Processed]) from every data table):
```dax
Last Updated Tabular =
UNION(
    ROW("Last Processed", FORMAT(MAX('FactTableName'[Last Processed]), "yyyy-MMM-dd h:mm AM/PM"),
        "Table Name", "FactTableName"),
    ROW("Last Processed", FORMAT(MAX('DimName'[Last Processed]), "yyyy-MMM-dd h:mm AM/PM"),
        "Table Name", "DimName")
    -- add one ROW() per data table
)
```

**Step 3: DW views for Source and DW freshness layers:**
```sql
CREATE VIEW [SSAS].[Last Updated Source] AS
SELECT [TableName] AS [Table Name], [UpdateDate] AS [Last Updated]
FROM [Internal].[LastUpdatedSource];

CREATE VIEW [SSAS].[Last Loaded DW] AS
SELECT [TableName] AS [Table Name], [LoadDate] AS [Last Loaded]
FROM [Internal].[IncrementalLoads];
```

**Step 4:** Add `Last Updated Source` and `Last Loaded DW` as regular import tables in the SSAS model, reading from the views above.

### Approach B — SSAS_ProcessLog Table (Alternative)

Use when you need a full pipeline audit trail (who triggered, duration, failures):

```sql
CREATE TABLE [Internal].[SSAS_ProcessLog] (
    LogID           INT IDENTITY(1,1) PRIMARY KEY,
    DatabaseName    NVARCHAR(255) NOT NULL,
    ProcessType     NVARCHAR(50)  NOT NULL,   -- 'Full', 'Default', 'Calculate'
    ProcessedAt     DATETIME      NOT NULL DEFAULT GETDATE(),
    ProcessStatus   NVARCHAR(20)  NOT NULL,   -- 'Success', 'Failed'
    DurationSeconds INT           NULL,
    ErrorMessage    NVARCHAR(MAX) NULL
);
```

ADO pipeline step after processing:
```powershell
$logSql = "INSERT INTO Internal.SSAS_ProcessLog
    (DatabaseName, ProcessType, ProcessedAt, ProcessStatus, DurationSeconds)
    VALUES (N'$DatabaseName', N'$ProcessType', GETDATE(), 'Success', $([int]$elapsed.TotalSeconds));"
Invoke-Sqlcmd -ServerInstance $DwSqlServer -Database $DwDatabase -Query $logSql
```

Both approaches can coexist: Approach A gives per-table freshness; Approach B gives pipeline history.

---

## 6. SSAS Model Description Standards

### Templates

**Table description:**
```
<Business name and description>.
Grain: one row per <entity/event>.
Can be grouped by: <related dimension tables>.
Cannot be grouped by: <list + reason>.
SCD Type: <1 / 2 / N/A>  (dimensions only)
Source: <source system and table> → DW <schema.TableName>.
```

**Measure description:**
```
<Plain English description of what this measure calculates>.
Valid groupings: <dimensions that produce meaningful results>.
Notes: <time intelligence requirements, semi-additive warnings, blank-handling>.
```

**Column description:**
```
<What this column contains and how it is derived>.
Source: <source system column or derivation formula>.
Classification: <InformationType> / <SensitivityLabel>  (if applicable)
```

### Agent Behaviour Rules

1. **Reviewing SSAS model**: flag all visible tables and non-hidden measures missing descriptions as 🟡 Medium findings.
2. **Reviewing a Power BI report**: flag missing Debug tab as 🟠 High finding — "Report has no Debug/Data Freshness tab — users cannot self-diagnose stale data."
3. **Generating a new measure or table**: always include a description following the template above.

---

## 7. Visual Performance Standards

> **Core principle**: Every visual on a page fires at least one DAX query to SSAS on page load. Fewer visuals = fewer queries = faster perceived load.

### 7.1 Visual Budget Per Page

| Report Type | Max Visuals | Notes |
|---|---|---|
| Executive summary (KPI page) | 6–8 | Target < 3 second load |
| Detailed analysis page | 10–12 | Target < 5 second load |
| Drill-through page | 8–10 | Only queried on demand (deferred) |
| Tooltip page | 1–3 | Must render < 1 second (shown on hover) |

**Agent rule**: Flag any page with > 12 visuals as 🟠 High finding — "Page has {N} visuals; recommend ≤ 12 for acceptable load time."

### 7.2 Matrix over Cards — Consolidation Pattern

> **Rule**: A single Matrix/Table with multiple measures usually generates fewer SSAS round-trips than multiple Card visuals showing the same data. The saving is most pronounced when measures are expensive or the model is slow. Validate with Performance Analyzer.

| Approach | DAX Queries | Notes |
|---|---|---|
| 5 separate Card visuals (one per KPI) | 5 queries (parallel) | More round-trips; parallel execution may mask cost on fast models |
| 1 Matrix with 5 measures as Values | 1 query | ✅ Preferred for 3+ related KPIs sharing filter context |

**Caveat**: Consolidation works best when KPIs share identical filter context. If each card has different "Filters on this visual", each unique filter context requires its own query regardless.

**How to style a Table/Matrix as KPI tiles:**
1. Use a Table or Multi-row Card with measures as values
2. For Matrix: place a single-value categorical field on Rows; hide the row header via formatting
3. Remove grid lines, totals, and column headers
4. Apply conditional formatting: background colour, font size, KPI icons per cell
5. Result: card-like appearance with fewer round-trips

**Other consolidation patterns:**
| Instead of... | Use... | Queries saved |
|---|---|---|
| 3+ separate Gauge visuals | 1 clustered bar with reference lines | N - 1 |
| Multiple text boxes with measures | 1 Table visual (measures as rows) | N - 1 |
| Separate charts per category | 1 chart with Legend (or Small Multiples) | N - 1 |
| KPI visual per metric | 1 Matrix with conditional icons | N - 1 |

**Agent rule**: When recommending KPI display for 3+ related metrics sharing filter context, recommend the consolidation pattern first. If the user prefers individual cards, note the trade-off in the decisions register.

### 7.3 Query Reduction Techniques

| Technique | Scope | Impact | How to apply |
|---|---|---|---|
| **Reduce visual count** | Page load | High — directly reduces initial queries | Consolidate visuals; use drill-through for detail |
| **Page-level filters over Slicers** | Page load | Medium — 1 query per slicer removed | Slicers are visuals with their own query; page filters are metadata (no query) |
| **Drillthrough over navigation** | Page load | High — defers all target page queries | Target page only fires queries when invoked |
| **Disable visual interactions** | Interactive | Medium — fewer queries after user clicks | Format → Edit interactions → **None** for non-related visuals |
| **Sync slicers sparingly** | Navigation | Medium — each synced page loads slicer | Only sync when persistent selection is essential |
| **Reduce slicer cardinality** | Interactive | Medium | Top N filter on slicer, or group into bands |

> **Note**: Disabling interactions reduces queries triggered by cross-filter clicks, not initial page load. To improve page load time, reduce visual count and slicer count.

**Agent rule**: During Phase 9 (Refresh & Performance), recommend disabling interactions for non-related visuals. Document which interactions are active and why.

### 7.4 Visual Type Performance Guidance

From fastest to slowest for the same data volume:

| Rank | Visual | Notes |
|---|---|---|
| 1 | Card / KPI | Single scalar query — fastest |
| 2 | Multi-row Card / Table / Matrix | Tabular scan, well-optimised engine path |
| 3 | Bar / Column / Stacked Bar | Group-by + aggregate — very fast |
| 4 | Line chart | Date axis aggregation — fast if grain is reasonable (month/quarter) |
| 5 | Combo chart | Two measures on same axis — slightly more than line |
| 6 | Scatter / Bubble | Two measures + category — moderate |
| 7 | Map (filled/bubble) | Geocoding overhead + Bing rendering |
| 8 | Decomposition tree | Dynamic DAX per expansion — can be very slow |

**Agent rule**: Prefer rank 1–4 visuals for executive summary pages. Maps and decomposition trees belong on detail/drill-through pages only.

### 7.5 Time-Series Grain and Data Points

| Date Grain | Max data points per series | When to use |
|---|---|---|
| Daily | 90 (one quarter) | Current quarter detail only |
| Weekly | 52 (one year) | Year-over-year trends |
| Monthly | 36 (three years) | Standard trending |
| Quarterly | 20 (five years) | Long-range strategic |

**Rule**: Never show > 365 daily data points in a single line chart on initial load. Default to month/quarter grain; let users drill to daily via drill-through or filter.

**Agent rule**: If a design calls for a date-axis line chart, confirm the default grain with the user. Flag daily grain for > 1 year as 🟡 Medium finding.

### 7.6 Interaction Settings Methodology

For each page during design:
1. List all slicers and visuals that can act as cross-filters
2. For each pair, ask: "Does filtering [Visual A] by selecting in [Visual B] provide analytical value?"
3. If **No** → set to None
4. If **Yes but not obvious** → set to **Filter** (not Highlight) — fewer visual queries
5. Document active interactions in the spec (Phase 9 output)

### 7.7 Conditional Formatting as Performance Tool

| Instead of... | Use... | Why faster |
|---|---|---|
| Multiple visuals shown/hidden by bookmarks | 1 visual with conditional format rules | Fewer visuals = fewer page-load queries |
| Separate "good/bad" indicator cards | Conditional background colour on a Matrix cell | 1 query vs N queries |
| Traffic-light icons as separate images | KPI conditional formatting (icons column) | No image rendering overhead |

> **Note**: Conditional formatting based on static thresholds is client-side (no query cost). Formatting driven by measure values may add columns to the visual query — still usually cheaper than separate visuals, but validate slow visuals with Performance Analyzer.

### 7.8 Performance Analyzer Workflow

**Mandatory for report review** (when reviewing an existing .pbix):

1. View → **Performance Analyzer** → Start recording
2. **Refresh visuals** (captures all page queries)
3. Sort by **Duration DESC**
4. Flag any visual > 3 seconds as 🟠 High finding
5. Flag any page where total > 8 seconds as 🔴 Critical finding

Breakdown:
- **DAX query** time > 2s → optimise the measure or model
- **Visual rendering** time > 1s → too many data points or complex custom visual
- **Other** time > 1s → SSAS capacity or network latency

**Agent rule**: When reviewing a report, if Performance Analyzer data is available (screenshot or export), use it to prioritise findings by actual measured impact rather than theoretical concerns.

> **PBIRS limitation**: Performance Analyzer is only available in Power BI Desktop during development. For deployed reports on PBIRS, capture query timings via SSAS Extended Events, DMVs (`$System.DISCOVER_SESSIONS`, `$System.DISCOVER_COMMANDS`), or DAX Studio Server Timings connected to the production SSAS instance.

---

## 8. Report Source Control

### Current State — Binary .pbix in Git

Reports (.pbix files) are stored as binary blobs in Git. This is the only viable approach for on-premises PBIRS deployments at this time.

**What is source-controlled (via TMDL, not .pbix):**
- Data model: tables, columns, measures, relationships, partitions, roles → TMDL folder in Git
- DAX measures: individual `.tmdl` files per table → full diff/merge capability
- Deployment pipeline: ADO Server pipeline deploys TMDL → SSAS

**What lives inside the .pbix (opaque binary):**
- Report page layout and visual definitions
- Visual-level conditional formatting rules
- Bookmarks, drill-through configuration
- Slicer and filter settings
- SSAS connection string
- Theme / formatting choices

### Limitations of Binary .pbix

| Limitation | Impact | Mitigation |
|---|---|---|
| Cannot diff between versions | No visibility into what changed between commits | Use descriptive commit messages; maintain a changelog in `design/report-changelog.md` |
| Cannot merge | Two people cannot work on the same .pbix simultaneously | Single-author workflow; coordinate via branching (one .pbix per branch) |
| Large file size over time | Git history grows; clone becomes slow | Use Git LFS for .pbix files (optional; evaluate if repo size > 500 MB) |
| No code review of visual changes | PRs cannot show what changed in the report | Attach before/after screenshots to the PR; describe changes in PR body |

### Best Practices for Binary .pbix Workflow

1. **One .pbix per logical report** — do not combine unrelated subject areas into a single file
2. **Commit messages must describe visual changes** — e.g., "Add drill-through page for regional detail; consolidate KPI cards into matrix on Exec Summary"
3. **Maintain `design/report-changelog.md`** per project — record page additions, visual changes, filter modifications, connection string changes with dates
4. **Single author at a time** — coordinate ownership; if two developers need to work on the same report, use sequential handoff (not parallel)
5. **Store alongside TMDL** — keep `.pbix` in the same repo as the SSAS model so the full stack is versioned together
6. **Tag deployments** — when publishing to PBIRS, tag the commit: `git tag -a pbirs-deploy-YYYY-MM-DD -m "Deployed to PBIRS"`

### What is NOT Available On-Premises

The following features require Power BI Service (cloud) and are **not applicable** to this stack:

| Feature | Requires | Status |
|---|---|---|
| PBIP format (folder-based report) | PBI Service for deployment | ❌ Not available for PBIRS |
| Git integration (workspace) | PBI Service Premium/Fabric | ❌ Cloud-only |
| Power BI Enhanced Report Format (.pbir) | Fabric | ❌ Cloud-only |
| Deployment pipelines (Dev/Test/Prod) | PBI Service Premium | ❌ Use ADO Server pipelines instead |

> **Research spike**: PBIP format may be usable as a *development-only* format (save as PBIP → diff/review → export back to .pbix for PBIRS deployment). Viability depends on whether the PBIRS-optimized PBI Desktop version supports PBIP save/open. See `design/spikes/pbip-on-prem-viability.md` if investigation is pursued.

### Agent Behaviour

- **Do not recommend** PBIP, Git integration, or cloud-only features for source control
- **Do recommend** descriptive commit messages, report changelog, and screenshot-based PR review
- When generating a new report spec, include a `## Source Control` section noting the .pbix file path and branch ownership
- Flag if multiple .pbix files appear to cover the same subject area (consolidation candidate)