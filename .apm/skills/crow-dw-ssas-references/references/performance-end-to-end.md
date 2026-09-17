<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# End-to-End Performance Reference

**Scope**: Performance guidance across the full data stack — from DW loading through SSAS Tabular to Power BI report visuals. Each layer's decisions cascade downstream; this document connects them into a single performance narrative.

**Stack**: SQL Server DW → SSAS Tabular (live connection) → Power BI Desktop → PBIRS

---

## The Performance Chain

```
DW Load (ELT)          →  SSAS Model Shape       →  DAX Measures        →  Report Visuals
─────────────────────     ─────────────────────     ─────────────────     ─────────────────────
• Batch size             • Row count per table     • Iterator avoidance  • Visual count per page
• Incremental strategy   • Cardinality             • Context transitions • Query reduction
• Partition switching    • Partition grain          • VAR caching         • Visual type selection
• Index strategy         • Encoding choices        • Filter propagation  • Interaction settings
```

**Key principle**: Performance problems at the visual layer are often symptoms of upstream design issues. Always diagnose from left to right.

---

## Layer 1 — DW Load (ELT) Performance

### Batch Sizing Heuristics

> **Agent behaviour**: When connected to the DW (live or via SSDT project), query actual row counts from `sys.partitions` before recommending a strategy. Present concisely — e.g., *"Fact.SalesOrder: 42M rows → incremental with partition switching."* Default to incremental watermark unless row counts justify otherwise.

| Scenario | Recommended Approach |
|---|---|
| Fact table < 5M rows total | Full truncate/reload — simplest, fast enough |
| Fact table 5M–50M rows | Incremental load (watermark-based `@StartDate`/`@EndDate`) |
| Fact table > 50M rows | Incremental + partition switching on current period |
| Dimension (SCD Type 1) < 500K rows | Full reload — safe for Type 1 (no history to preserve) |
| Dimension (SCD Type 2) any size | Incremental with change detection — full reload destroys history |
| Dimension > 500K rows | Incremental by change date; consider hash-based change detection |

### Incremental Load Performance Rules

1. **Narrow the window** — load only changed rows. Use `Internal.IncrementalLoads` watermark.
2. **Index staging tables at end of load** — NCI on natural key after `INSERT`, not before (avoids index maintenance during bulk insert).
3. **DELETE + INSERT over MERGE for facts** — avoids MERGE lock escalation on large tables; DELETE targets only changed rows via JOIN to staging.
4. **Avoid SELECT * from source** — extract only required columns in the source query.
5. **MAXDOP** — controlled at the server/Resource Governor level by the DBA. If processing queries compete with OLTP, flag for DBA review (not set per-query by these agents).

### Partition Switching Performance

When fact tables exceed 10M rows with monthly grain:

```sql
-- Load into staging partition (identical schema + constraints)
ALTER TABLE Staging.SalesPartition
    SWITCH TO Fact.Sales PARTITION $partition.pfMonthly(N'2024-01-01');
```

**Benefits**: Zero-lock swap; no row-by-row DELETE/INSERT; SSAS can process only the switched partition.

### Processing Window Budget

| Activity | Typical % of nightly window |
|---|---|
| Source extracts (SSIS Execute SQL) | 10–20% |
| Staging → Dimension loads | 10–15% |
| Staging → Fact loads | 30–40% |
| SSAS ProcessData (partitions) | 20–30% |
| SSAS ProcessRecalc | 5–10% |

**Rule**: If total processing exceeds 70% of the available window, optimise the largest time consumer first (usually fact loads or SSAS processing).

---

## Layer 2 — SSAS Model Shape

### Model Size Impact on Performance

| Model Metric | Target | Warning | Action |
|---|---|---|---|
| Total model RAM | < 50% of server RAM | > 70% of server RAM | Aggregate tables, reduce cardinality, column pruning |
| Single table rows | < 50M | > 100M | Partition + aggregation tables |
| Column cardinality | < 1M distinct | > 5M distinct | Hide/remove, use as drill-through only |
| Relationship cardinality | 1:many preferred | Many:many | Bridge table + TREATAS |
| Bidirectional filters | 0 preferred | > 2 | Rewrite DAX with CROSSFILTER or TREATAS |

### Cardinality Reduction Strategies

1. **Remove unused columns** — every column consumes RAM even if hidden. If no measure or relationship references it, drop it from the SSAS view.
2. **Reduce string precision** — truncate long descriptions (> 100 chars) unless needed for drill-through.
3. **Split high-cardinality columns** — transaction IDs, free-text notes → separate drill-through table with inactive relationship.
4. **Use integer keys** — surrogate keys (INT) compress better than composite natural keys (NVARCHAR).
5. **Aggregate tables** — for > 50M row facts: create a pre-aggregated table at month/category grain for summary visuals. Note: SSAS Tabular on-prem has no automatic aggregation awareness — consumers must route to summary tables explicitly via measure logic (`IF`/`SWITCH` on grain detection) or by exposing separate measures for summary vs detail.

### Partition Strategy for Processing Performance

| Fact Table Rows | Partition Grain | Processing Strategy |
|---|---|---|
| < 5M | None (single partition) | ProcessFull nightly |
| 5M–50M | Annual | ProcessData current year only; recalc all |
| 50M–200M | Monthly | ProcessData current + prior month; recalc all |
| > 200M | Monthly + aggregation | ProcessData current month; aggregation table rebuilt weekly |

**Processing order** (always):
1. Dimensions (parallel where no dependencies)
2. Fact partitions (parallel across tables; sequential within table if resource-constrained)
3. ProcessRecalculate (triggers calculated columns, calc groups, relationships)

### Encoding Hints

```tmdl
-- Force value encoding on frequently aggregated numeric columns (after benchmarking)
column SalesAmount
    encodingHint: Value

-- Leave hash encoding for string/FK columns (default)
column CustomerName
    encodingHint: Hash
```

**Guidance**: Use VertiPaq Analyzer to identify large/high-cardinality columns. Prefer data type and cardinality reduction first. Only set `encodingHint` after benchmarking with DAX Studio Server Timings — encoding overrides can harm performance if applied blindly.

---

## Layer 3 — DAX Measure Performance

### Performance Rules (Ranked by Impact)

| # | Rule | Impact | Example |
|---|---|---|---|
| 1 | **Avoid iterators on large tables** | 🔴 High | `SUMX(Sales, ...)` on 50M rows → use pre-computed column |
| 2 | **Minimise context transitions** | 🔴 High | Nested `CALCULATE` inside `SUMX` → extract to VAR |
| 3 | **Use VAR to cache intermediate results** | 🟠 Medium | Same sub-expression evaluated twice → assign to VAR |
| 4 | **Filter dimension columns, not fact tables** | 🟠 Medium | `FILTER(ALL(FactTable), ...)` scans entire fact → pass Boolean predicate on dimension column directly in CALCULATE |
| 5 | **Avoid DISTINCTCOUNT on high-cardinality** | 🟡 Low–Med | > 1M distinct values → pre-aggregate at load time (APPROXIMATEDISTINCTCOUNT is not available for SSAS Tabular Import / live-connect) |
| 6 | **Use DIVIDE() not `/`** | 🟡 Low | Avoids error handling overhead |
| 7 | **Limit IF/SWITCH branches** | 🟡 Low | > 5 branches → consider upstream classification column |

### Context Transition Patterns to Avoid

```dax
-- ❌ BAD: Context transition inside iterator — O(n) × O(n) risk
Sales with Tax =
SUMX( Sales, [Unit Price] * [Quantity] * (1 + CALCULATE( MAX( TaxRate[Rate] ) )) )

-- ✅ GOOD: Pre-resolve outside iterator
Sales with Tax =
VAR _TaxRate = MAX( TaxRate[Rate] )
RETURN SUMX( Sales, [Unit Price] * [Quantity] * (1 + _TaxRate) )
```

### Calculation Group Benefits

Calculation groups reduce measure proliferation and improve maintainability and consistency. Performance is comparable to hand-written equivalents (not inherently faster — `SELECTEDMEASURE()` still evaluates the full measure). Use them when governance matters:
- > 5 base measures × > 3 time-intelligence variants to manage
- Consistency guarantee: all measures get the same time-intelligence logic
- Reduced maintenance: one fix applies to all measures

**Rule**: Prefer Calculation Groups for maintainability and consistency, not for raw performance. Benchmark with DAX Studio if performance is a concern.

### When Complex DAX Is Justified

Not all iterators are bad. Document the reason when using:
- `FILTER(ALL(...))` for Events in Progress (cumulative pattern)
- `SUMX` with row-level calculation that genuinely cannot be pre-computed
- Semi-additive patterns (`LASTDATE`, `LASTNONBLANK`) for balances/inventory

---

## Layer 4 — Report Visual Performance

### Visual Budget Per Page

| Report Type | Max Visuals | Reasoning |
|---|---|---|
| Executive summary (KPI page) | 6–8 | Each visual = 1+ DAX query; keep it snappy |
| Detailed analysis page | 10–12 | Users expect slightly longer load for detail |
| Drill-through page | 8–10 | Only rendered on demand (deferred queries) |
| Tooltip page | 1–3 | Must render < 1 second |

**Every visual on a page fires at least one query to SSAS on page load.** Fewer visuals = fewer concurrent queries = faster perceived load.

### Matrix vs Cards — The Performant Pattern

> **Rule**: A single matrix visual with multiple measures usually generates fewer SSAS round-trips than multiple individual card visuals showing the same data. The saving is most pronounced on slow models or when measures are expensive. Validate with Performance Analyzer.

| Approach | Queries Generated | Performance |
|---|---|---|
| 5 separate Card visuals (one per KPI) | 5 queries (run in parallel) | More round-trips; parallel execution may mask cost on fast models |
| 1 Matrix with 5 measures as Values | 1 query | ✅ Single round-trip — preferred for 3+ related KPIs |

**Caveat**: If each card has different filter context ("Filters on this visual"), the matrix consolidation is not semantically equivalent — each unique filter context requires its own query regardless of visual type. Consolidation works best when KPIs share identical filter context.

**How to style a Matrix/Table as KPI tiles:**
1. Use a Table or Multi-row Card visual with measures as values
2. For Matrix: place a single-value categorical field on Rows; hide row headers via formatting
3. Remove grid lines, totals, and column headers
4. Apply conditional formatting: background colour, font size, KPI icons per cell
5. Result: card-like appearance with fewer queries than separate Card visuals

**Other consolidation patterns:**
- 3 gauges → 1 clustered bar with reference lines
- Multiple text boxes with measures → 1 table visual with measure names as rows
- Separate charts per category → 1 chart with legend (or Small Multiples visual)

### Query Reduction Techniques

| Technique | Effect | Scope | How |
|---|---|---|---|
| **Reduce visual count per page** | Fewer queries on initial page load | Page load | Consolidate visuals (Matrix over Cards, drill-through for detail) |
| **Use page-level filters over slicers** | 1 fewer query per slicer removed | Page load | Slicers are visuals with their own query; filters are metadata |
| **Drillthrough over navigation** | Defers all target page queries | Page load | Target page only fires queries when invoked |
| **Disable visual interactions** | Fewer queries on user click (cross-filter) | Interactive | Select visual → Format → Edit interactions → None for non-related visuals |
| **Sync slicers sparingly** | Fewer queries on page navigation | Navigation | Each synced page loads the slicer query when navigated to |
| **Use bookmarks to swap visuals on same page** | Avoids multiple visible visuals | Interactive | Toggle visibility instead of stacking separate visuals |

> **Note**: Disabling visual interactions improves responsiveness after user selections (cross-filtering), but has no effect on initial page load. To improve page load, reduce visual count and slicer count.

### Visual Type Performance Ranking

From fastest to slowest for the same data volume:

| Rank | Visual | Why |
|---|---|---|
| 1 | Card / KPI | Single scalar query |
| 2 | Multi-row Card / Table / Matrix | Tabular scan, well-optimised engine path |
| 3 | Bar / Column chart | Group-by + aggregate, well-optimised |
| 4 | Line chart (time series) | Date axis + aggregate — fast if date granularity is reasonable |
| 5 | Scatter plot | Two measures + category — moderate |
| 6 | Map (filled/bubble) | Geocoding overhead + rendering cost |
| 7 | Decomposition tree | Dynamic drill paths — query per expansion |
| 8 | Custom visual (certified) | Depends on implementation — profile individually |

### Interaction Settings Best Practices

```
Default: All visuals cross-filter all other visuals on the page
Optimised: Only logically related visuals interact
```

**Process:**
1. For each slicer/visual on the page, ask: "Does filtering [X] by [Y] provide analytical value?"
2. If No → set interaction to **None**
3. If Yes but causes slow rendering → set to **Filter** (not Highlight) — fewer queries

### Conditional Formatting as Performance Tool

Instead of: Multiple visuals that conditionally appear (Show/Hide via bookmarks or rules)
Use: Single visual with conditional formatting that changes colour/icon based on measure value

- Fewer visuals on the canvas = fewer queries on page load
- Conditional formatting based on **static rules** (thresholds) is client-side and adds no query cost
- Conditional formatting based on **measure values** may add columns to the visual query — still usually cheaper than separate visuals, but validate slow visuals with Performance Analyzer

---

## Layer 5 — Cross-Layer Performance Patterns

### Pattern: High-Cardinality Dimension Slows Everything

| Symptom | Layer | Fix |
|---|---|---|
| SSAS processing slow | Model | Split into descriptive vs. key tables; only key table has relationship |
| DAX DISTINCTCOUNT slow | DAX | Pre-aggregate at load time into `Fact.DailyDistinctCounts` |
| Slicer loads slowly | Visual | Use Top N filter on slicer, or replace with Search box filter |
| Filter pane slow | Visual | Move high-cardinality fields to drill-through only |

### Pattern: Date Grain Mismatch

| Symptom | Layer | Fix |
|---|---|---|
| SSAS model too large | Model | Aggregate to date (not datetime) in DW load |
| Time-series chart renders slowly | Visual | Use month/quarter grain for trends; date only for drill-through |
| Line chart shows 365+ points | Visual | Default filter to current quarter; full year via drill-through |

### Pattern: Too Many Measures in One Visual

| Symptom | Layer | Fix |
|---|---|---|
| Matrix with 20+ measures | Visual | Split into multiple pages or use Calculation Group + slicer |
| Executive page loads > 5 seconds | Visual | Reduce to 5–7 KPIs; detail on sub-pages |
| Multi-row card with 10 measures | Visual | Replace with Matrix (single query) |

### Pattern: Semi-Additive Measure Causes Full Scan

| Symptom | Layer | Fix |
|---|---|---|
| `LASTNONBLANK` on large fact | DAX | Ensure Date filter context is narrow; add partition |
| Inventory balance slow at detail | Model | Periodic snapshot fact (pre-computed in DW load) |
| Balance measures slow in Matrix | Visual | Limit to month grain; daily only via drill-through |

---

## Performance Diagnostic Workflow

When a report is slow, diagnose in this order:

### Step 1: Identify the Slow Visual
- Use **Performance Analyzer** in Power BI Desktop (View → Performance Analyzer → Start recording → Refresh visuals)
- Sort by Duration DESC — target the top 3 slowest visuals

### Step 2: Classify the Bottleneck
- **DAX query** duration > 2 seconds → DAX/model issue (Layer 3 or 2)
- **Visual rendering** duration > 1 second → too many data points or complex visual (Layer 4)
- **Other** duration high → connectivity or SSAS capacity (Layer 2)

### Step 3: Fix by Layer

| Bottleneck | Action |
|---|---|
| DAX query slow | Open query in DAX Studio → Server Timings → check SE (storage engine) vs FE (formula engine) |
| SE queries dominate | Model shape issue — cardinality, missing aggregation, encoding |
| FE time dominates | DAX complexity — iterators, context transitions, nested CALCULATE |
| Visual rendering slow | Too many data points — add Top N, reduce grain, consolidate visuals |
| Multiple visuals slow | Page has too many visuals — consolidate, use drill-through |

### Step 4: DAX Studio Profiling

```dax
-- Enable Server Timings in DAX Studio, then run:
EVALUATE
SUMMARIZECOLUMNS(
    'Calendar'[Year],
    'Calendar'[Month Name],
    "Total Sales", [Total Sales Amount]
)
```

Check:
- Total SE queries (fewer is better — model design)
- SE query duration (shorter is better — encoding, partitions)
- FE duration (shorter is better — DAX simplicity)
- Materialisations (0 is ideal — each means a temp table)

### Step 5: PBIRS / Production Diagnostics

Performance Analyzer is only available in Power BI Desktop. For deployed reports on PBIRS with SSAS live connection, use server-side tools:

| Tool | What it captures | When to use |
|---|---|---|
| **DAX Studio → Server Timings** (connected to SSAS) | SE/FE split, query plan, materialisations for a specific measure | Developer reproducing a reported slow query |
| **SSAS Extended Events** (`QueryEnd`, `QueryBegin`) | All queries hitting the model — duration, user, DAX text | Ongoing monitoring; identify top-N slow queries across all users |
| **SSAS DMVs** (`$System.DISCOVER_SESSIONS`, `DISCOVER_COMMANDS`) | Active sessions, running queries, memory pressure | Real-time "who/what is hitting the server now" |
| **PBIRS Execution Log** (`ExecutionLog3` view in `ReportServer` DB) | Report render time, data retrieval time, rows returned, parameters | "Which published reports are slow for end users?" |
| **SQL Server Query Store / Extended Events** (on the DW) | SSAS processing queries hitting the DW engine | Processing window optimisation |

**Agent rule**: When reviewing performance of a deployed report (not a .pbix in Desktop), recommend SSAS Extended Events + `ExecutionLog3` as the primary diagnostic path. Do not tell users to use Performance Analyzer for production troubleshooting.

### Step 6: RLS Performance Impact

Row-Level Security adds per-query filter overhead. Dynamic RLS (TREATAS against a permissions table) costs more than fixed roles.

**Benchmark method** (DAX Studio):
1. Run a representative query **without** a role (baseline).
2. Re-run the same query **with** a role (Connection → Roles → select role; set EffectiveUserName).
3. Compare total duration. Overhead < 15% of baseline is acceptable; > 30% warrants investigation.

**Common causes of RLS slowness:**
- Permissions table has high cardinality (> 50K rows) — pre-aggregate or filter upstream.
- `PATHCONTAINS` hierarchy-based RLS on deep trees — flatten to a bridge table.
- Bidirectional cross-filter on the secured relationship — avoid; use TREATAS instead.

**Agent rule**: During Mode B (Tabular Review), if dynamic RLS roles exist, flag for performance validation and suggest the benchmark method above.

---

## Performance SLAs (Organisation Defaults)

| Metric | Target | Action Threshold | Notes |
|---|---|---|---|
| Executive page initial load | < 3 seconds | > 5 seconds = must optimise | ≤ 8 visuals, warm cache |
| Detail page initial load | < 5 seconds | > 8 seconds = must optimise | ≤ 12 visuals, warm cache |
| Slicer filter response | < 2 seconds | > 4 seconds = reduce cardinality or disable interactions | Interactive — after user click |
| Drill-through navigation | < 3 seconds | > 5 seconds = reduce target page visuals | Deferred rendering |
| SSAS processing (nightly) | < 60% of window | > 80% = partition/incremental strategy needed | |
| Model RAM | < 50% of server RAM | > 70% = aggregation tables or column pruning | Account for processing headroom |

> **Warm vs cold cache**: First user after nightly processing hits cold SSAS cache and may experience 2–3× longer load. Consider adding cache-warming queries (scheduled DAX queries against key pages' measures) after processing completes.

---

## Performance Checklist for Architects and Report Designers

### DW Layer
- [ ] Incremental loads use narrow date windows (not full reload)
- [ ] Fact tables > 10M rows use partition switching or targeted DELETE/INSERT
- [ ] Staging indexes added after bulk insert, not before
- [ ] Source extracts select only required columns

### SSAS Layer
- [ ] No unused columns in SSAS views (every column in model is referenced by a measure, relationship, or slicer)
- [ ] High-cardinality columns (> 1M distinct) are hidden or in drill-through-only tables
- [ ] Encoding hints applied only after VertiPaq Analyzer review and benchmarking
- [ ] Bidirectional relationships: 0 (or documented justification)
- [ ] Partition strategy matches table size (see partition table above)

### DAX Layer
- [ ] No iterators on tables > 5M rows without documented justification
- [ ] No nested CALCULATE inside SUMX/FILTER
- [ ] VAR used for any sub-expression referenced more than once
- [ ] Calculation groups used when > 5 measures × > 3 time variants
- [ ] DIVIDE() used for all division operations

### Visual Layer
- [ ] Executive/summary pages: ≤ 8 visuals
- [ ] Detail pages: ≤ 12 visuals
- [ ] No individual Card visuals where a Matrix could consolidate (3+ related KPIs)
- [ ] Visual interactions reviewed — non-related visuals set to "None"
- [ ] Slicers minimised (use page filters where possible)
- [ ] High-cardinality dimensions not in visible slicers (use search or drill-through)
- [ ] Time-series charts default to quarter/month grain (not daily for full year)
- [ ] Performance Analyzer run: no visual > 5 seconds

---

## Trusted References

- **SQLBI** — DAX optimisation, VertiPaq internals, model design patterns
- **Guy in a Cube** — practical Power BI performance tips, visual design, report optimisation
- **Kimball Group** — DW physical design, partition strategy, aggregate navigation
- **Microsoft Learn** — SSAS processing, columnstore, performance tuning documentation
