<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# DAX Studio Workflow — Performance Analysis & Review

This reference guides the Copilot agent through DAX Studio-based performance analysis and review workflows. It is used by:

- **Mode B** — SSAS Tabular Model Review
- **Mode D** — DAX Measure Review

When a user reports a slow measure or requests a performance review, follow the workflow in this document and gather the evidence described in section 8.

## Org conventions (non-negotiable)

- The org runs **SSAS Tabular only**. DAX only — never write or recommend MDX.
- The date dimension is the SSAS table **`Calendar`**. All time-intelligence patterns must use it and it must be marked as a Date Table.
- Reports are authored in Power BI and published to **PBIRS** using a **live connection** to SSAS Tabular (import mode is in the model, not in the report).
- Approved performance tool is **DAX Studio** (free) — https://daxstudio.org. Do not recommend Tabular Editor 3, Profiler traces, or other paid/commercial tools in findings.
- Never reference Multidimensional, MDX, TE3, or YAML deployment pipelines in review output.

## 1. Connecting DAX Studio to SSAS Tabular

1. Launch DAX Studio.
2. In the connection dialog, choose **SSAS** and enter the server. Use **Windows Authentication** (on-premises Active Directory — the org does not use service principals for SSAS).
3. Connection string format:

   ```
   Data Source=ServerName\InstanceName; Initial Catalog=ModelName
   ```

4. Select the database (model) from the dropdown and click **Connect**.

### Connecting via PBIRS live connection (advanced)

If you need to inspect a model exactly as a PBIRS report sees it:

1. Open the `.pbix` report in **Power BI Desktop** (it must be a live connection to SSAS Tabular).
2. Use the **External Tools** ribbon → **DAX Studio** button. DAX Studio attaches to the same SSAS session.

### Recommendation

For performance work, always connect **directly to the SSAS instance** rather than via PBIRS / Power BI Desktop. The intermediate session adds noise to Server Timings and can mask the real bottleneck.

## 2. Server Timings

Server Timings is the primary diagnostic surface for measure performance.

### What it measures

- **FE (Formula Engine)** — time the DAX engine spends evaluating the measure expression (single-threaded, in-memory).
- **SE (Storage Engine)** — time spent reading data from the VertiPaq column store (multi-threaded, cacheable).
- **SE Cache** — portion of SE time satisfied from the VertiPaq cache (effectively free).
- **Direct Query** — time spent on a DirectQuery source. In this org this should be **0**; anything non-zero is a finding (the standard is import-mode Tabular).

### Rule of thumb

- If **FE > 20%** of total time → the DAX expression is the bottleneck. Focus on simplifying the expression and removing anti-patterns.
- If **SE dominates** → data volume / column cardinality / model design is the bottleneck. Focus on the model (encoding, cardinality, relationships).

### How to enable

1. DAX Studio → **Home** tab → tick **Server Timings**.
2. (Optional but recommended) Also tick **Clear Cache then Run** to measure cold-cache performance, or **Run** alone to measure warm-cache.
3. Execute the query.
4. Review the **Server Timings** pane. Columns: **Total**, **FE**, **SE**, **SE Cache**, **Direct Query**, plus a list of SE queries (xmSQL).

### Interpreting results

| Pattern                                 | Diagnosis                                            | Action                                                                 |
| --------------------------------------- | ---------------------------------------------------- | ---------------------------------------------------------------------- |
| FE > 50% of total                       | Complex DAX expression                               | Simplify with `VAR`, check anti-patterns in section 5                  |
| SE very high, many SE queries           | Low-cardinality columns not encoded well, or many context transitions | Review column encoding hints in the SSAS model; reduce iterators       |
| SE high, **1** large SE query           | Large table scan with no useful filter               | Add partitioning, push filter context, or reduce columns touched       |
| Direct Query > 0                        | Mixed mode — **not** the org standard                | Raise as a finding — the org standard is import-mode Tabular           |
| High SE Cache hit ratio on repeated run | Healthy — cache is doing its job                     | Make sure baseline is captured from a **warm** run (see section 6)     |
| Near-zero SE Cache on repeated run      | Non-deterministic measure or cache invalidation bug  | Check for `NOW()`, `TODAY()` inside the measure, or volatile filters   |

## 3. Query Plan

Enable via: DAX Studio → **Home** → **Query Plan** checkbox. Two plans are produced for every query:

- **Logical Query Plan (LQP)** — what DAX *intends* to do. High-level operations as the formula engine sees them.
- **Physical Query Plan (PQP)** — what VertiPaq *actually executes*. Storage scan operations and intermediate materialisations.

### Key operators to look for

- **`CrossJoin`** in the PQP — expensive. Almost always caused by an unnecessary `FILTER(ALL(Table))` or a missing relationship forcing a cartesian product. See section 5.
- **`Spool`** — intermediate materialisation. A few are normal; many or large spools indicate complex context transitions or a measure being recomputed in a way that defeats the engine.
- **`GroupSemiJoin`** — relationship traversal. Note the **cardinality** of the join side; high cardinality here means a relationship is being walked across millions of rows per outer row.

Use the plan together with Server Timings: the plan tells you *what* is happening, Server Timings tells you *how expensive* it is.

## 4. VertiPaq Analyzer

VertiPaq Analyzer reports on the structure and size of the model itself — independent of any single query.

### Open via

- DAX Studio → **Advanced** tab → **View Metrics**.
- Or use the standalone **VertiPaq Analyzer** Excel add-in against an exported `.vpax` file.

### Key metrics to review

| Metric             | What to look for                                                                                                            |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| Table size (MB)    | Large fact tables are expected; unexpectedly large **dimension** tables almost always indicate a cardinality issue.         |
| Column cardinality | Very high-cardinality string columns compress poorly. Free-text and GUID columns are red flags.                             |
| Column encoding    | `HASH` (used for high-cardinality / strings) vs `VALUE` (low-cardinality / integers). `VALUE` is more efficient — prefer it where the column is used in relationships or measures. |
| Relationships      | Many-to-many and bidirectional relationships are expensive — flag them in the finding.                                      |
| Hierarchies        | Materialised user hierarchies add size; only create them when a user genuinely requires drill-down in reports.              |

### Generating a `.vpax` file

```
DAX Studio → Advanced → Export Metrics → Save as .vpax
```

The `.vpax` contains **metadata only** (column names, sizes, cardinalities, relationships). It does **not** contain row data and is safe to share with the wider team for review without exposing business data.

## 5. Common performance bottlenecks and fixes

| Bottleneck                                          | Symptoms                                       | Fix                                                                                              |
| --------------------------------------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `FILTER(ALL(Table))`                                | High FE, `CrossJoin` in PQP                    | Replace with `KEEPFILTERS()` or restructure to `CALCULATE(<expr>, <condition>)`                  |
| No date relationship to `Calendar`                  | Time-intelligence scans the entire fact table  | Mark `Calendar` as Date Table; ensure an **active** relationship to the fact date key            |
| High-cardinality string column in relationship      | Large model size, slow joins                   | Add a surrogate integer key in the warehouse; hide the string key; relate on the integer         |
| Bidirectional relationship                          | Slow cross-filter measures, unexpected results | Change to single-direction; use `CROSSFILTER()` inside the specific measures that need it        |
| Iterator over fact table (`SUMX` with complex expr) | High FE, slow                                  | Pre-calculate the per-row value as a calculated column in the model, or simplify the expression  |
| `COUNTROWS(FILTER(Table, <condition>))`             | FE scan anti-pattern                           | Replace with `CALCULATE(COUNTROWS(Table), <condition>)`                                          |
| Semi-additive measure without `LASTNONBLANK`        | Wrong results **and** slow                     | Use the `LASTNONBLANK` / `LASTNONBLANKVALUE` pattern — see `sqlbi-dax-patterns.md`               |

For semi-additive measures, snapshot facts, and other standard patterns, refer to **`sqlbi-dax-patterns.md`** rather than reproducing them here.

## 6. Benchmarking workflow

Step-by-step process for benchmarking a slow measure. Follow this exactly when producing evidence for a review finding.

1. **Warm up the cache.** Run the query twice before recording — the first run is always cold and is not representative of steady-state user experience (unless you are specifically measuring cold-cache, e.g. after model processing).
2. **Capture the baseline.** Enable Server Timings; run the production query (the actual report query, or the smallest query that reproduces the issue); record **Total**, **FE**, **SE**.
3. **Isolate the measure.** Create a minimal DAX query that exercises only the measure under test:

   ```dax
   EVALUATE
   ROW(
       "Result", [Measure To Test]
   )
   ```

   If the issue requires filter context to reproduce, wrap in `CALCULATETABLE` rather than relying on a slicer:

   ```dax
   EVALUATE
   CALCULATETABLE(
       ROW( "Result", [Measure To Test] ),
       'Calendar'[Year] = 2024
   )
   ```

4. **Identify the bottleneck.** Check the FE vs SE ratio (section 2). Review the Query Plan for `CrossJoin` / large `Spool` (section 3).
5. **Implement one fix at a time.** Do not batch multiple changes — you will not know which one actually helped.
6. **Validate.** Re-run the benchmark (warm-cache, same query). Compare to the baseline.
7. **Document.** Record before/after Total/FE/SE as evidence in the review finding.

## 7. DMV queries for model health (run in DAX Studio)

These INFO-function queries complement VertiPaq Analyzer for a quick model health check. Run them in DAX Studio against the SSAS Tabular model.

```dax
-- Table row counts
EVALUATE
SELECTCOLUMNS(
    INFO.TABLES(),
    "Table",    [Name],
    "Rows",     [Rows In Table],
    "IsHidden", [Is Hidden]
)
ORDER BY [Rows In Table] DESC
```

```dax
-- Measure count per table
EVALUATE
SUMMARIZECOLUMNS(
    INFO.MEASURES()[Table ID],
    "MeasureCount", COUNTROWS( INFO.MEASURES() )
)
```

```dax
-- Relationship overview
EVALUATE
SELECTCOLUMNS(
    INFO.RELATIONSHIPS(),
    "From Table",  [From Table Name],
    "To Table",    [To Table Name],
    "Active",      [Is Active],
    "CrossFilter", [Cross Filtering Behavior]
)
```

## 8. Review finding evidence standards

When a performance issue is reported in a **Mode B** (SSAS Tabular Model Review) or **Mode D** (DAX Measure Review) finding, the finding **MUST** include:

- The DAX Studio **Server Timings** output — FE time, SE time, total time (warm-cache).
- The exact DAX **query used to reproduce** the issue (paste into the finding so it can be re-run).
- The specific **Query Plan node** that identifies the root cause (e.g. `CrossJoin` on `Sales`/`Calendar`, large `Spool` over `Product`).
- A **before / after benchmark** if a fix is being recommended — both numbers measured with the same warm-cache methodology described in section 6.

Without this evidence, a performance finding **must be flagged as 🔵 LOW (unverified)** rather than a higher severity. Severity escalations require measured evidence.
