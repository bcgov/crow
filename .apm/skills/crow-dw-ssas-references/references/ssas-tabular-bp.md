<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# Analysis Services Tabular Best Practices Reference

Targeting: SQL Server Analysis Services (SSAS) Tabular mode, compatibility levels 1200–1600,
on-premises SQL Server 2016–2022, with Power BI Report Server (PBIRS) live connections.

---

## Table of Contents
1. [Model Formats: BIM vs TMDL](#model-formats-bim-vs-tmdl)
2. [Naming Conventions](#naming-conventions)
3. [Compatibility Levels](#compatibility-levels)
4. [Relationship Design](#relationship-design)
5. [Partition Strategy](#partition-strategy)
6. [Column Encoding](#column-encoding)
7. [Calculation Groups](#calculation-groups)
8. [Perspectives](#perspectives)
9. [Row-Level Security (RLS)](#row-level-security-rls)
10. [Kerberos & Windows Authentication](#kerberos--windows-authentication)
11. [SSAS Processing Strategies](#ssas-processing-strategies)
12. [XMLA / TMSL Scripting](#xmla--tmsl-scripting)
13. [VertiPaq Analyzer](#vertipaq-analyzer)
14. [DAX Studio](#dax-studio)
15. [Tabular Editor 2](#tabular-editor-2) *(includes BPA official rules, org-specific rules, community scripts)*
16. [ALM Toolkit](#alm-toolkit)
17. [Model Deployment](#model-deployment)
18. [Backup and Restore](#backup-and-restore)
19. [Power BI Report Server Live Connection Constraints](#power-bi-report-server-live-connection-constraints)
20. [DMV Reference Queries](#dmv-reference-queries)
22. [Common Review Findings](#common-review-findings)

---

## Model Formats: BIM vs TMDL

### BIM (Business Intelligence Model)
- Single `Model.bim` JSON file — entire model in one place; difficult to diff in source control.
- Required for SSDT (Visual Studio) projects; supported by all CL 1200+.

### TMDL (Tabular Model Definition Language)
- Splits model into folder + per-object files — **superior for source control** (granular diffs, merge-friendly).
- Readable YAML-like syntax: tables, measures, columns, partitions, relationships, roles each in separate files.
- **BIM ↔ TMDL via TE2:** File → Save as → To folder (BIM→TMDL) or → Single file .bim (TMDL→BIM)

---

## Developer Workflow (Git + Tabular Editor + ADO Server)

### Environment Naming

| Environment | SSAS Database Name Pattern | Who deploys |
|---|---|---|
| Local dev | `<ModelName>_DEV` | Developer (Tabular Editor, manual) |
| Shared test | `<ModelName>_TEST` | ADO pipeline |
| UAT | `<ModelName>_UAT` | ADO pipeline |
| Production | `<ModelName>_PROD` | ADO pipeline |

Example: `EAO_Tabular_DEV`, `EAO_Tabular_TEST`, `EAO_Tabular_UAT`, `EAO_Tabular_PROD`

> **Rule**: Developers deploy only to `_DEV`. ADO Server owns all promotions from TEST onwards.

### Step-by-Step Developer Workflow

1. **Git pull** — `git pull origin main` (or feature branch)
2. **TE2: Open from folder** — File → Open → From folder → `SSAS\<ModelName>\` *(always from TMDL folder, not .bim)*
3. **TE2: Deploy to DEV** — Model → Deploy → Server: `<ssas-dev-server>`, Database: `EAO_Tabular_DEV`, Options: Overwrite ✓, Deploy roles ✓
4. **TE2: Open from DB** — File → Open → From DB → `EAO_Tabular_DEV` *(switch to live-connected mode to work against actual deployed state)*
5. **Edit + auto-deploy** — Edit objects → Ctrl+S auto-deploys to `_DEV`
6. **Process** — SSMS → right-click `EAO_Tabular_DEV` → Process *(only when required — see table below)*
7. **Test** — Power BI Desktop or Excel → Get Data → SSAS → `EAO_Tabular_DEV` (Live connection)
8. **TE2: Save as folder** — File → Save as → To folder → overwrite `SSAS\<ModelName>\`
9. **Git commit** — `git diff` → review changed `.tmdl` files → `git add -A` → `git commit -m "feat: ..."` → `git push`
10. **ADO pipeline** — auto-triggers on push: Build validation → Deploy to TEST → UAT gate → PROD

### When to Process After Deploying

No processing needed for: measure/DAX changes, format strings, display folders, role/RLS changes.

| Change Type | Process Type |
|---|---|
| Add new table (with partition) | ProcessFull |
| Add new column from DW | ProcessFull or ProcessAdd |
| Change partition query | ProcessPartition |
| Add/modify relationship | ProcessRecalculate |
| Rename source column | ProcessFull |
| First-time deployment | ProcessFull |

Process SSAS: SSMS right-click → Process, or TMSL `"type": "full"` / `"calculate"` / `"dataOnly"`.

### TMDL Folder Structure in Git

```
SSAS/EAO_Tabular/  database.tmdl  model.tmdl  tables/  relationships/  roles/  cultures/  perspectives/  expressions/
```

Adding a measure changes only `tables/<TableName>.tmdl`; adding a role creates only `roles/<RoleName>.tmdl`.

**Open from DB vs Folder:** Start session → Folder; after deploying to `_DEV` → DB; reviewing TEST/UAT/PROD → DB (read-only). **Never "Save as folder" from a non-DEV DB.**

**Connect PBI Desktop to DEV:** Get Data → Analysis Services → Server: `<ssas-dev-server>` → Database: `EAO_Tabular_DEV` (Live connection). ADO pipeline updates to `_PROD` on deploy.

---

## Naming Conventions

| Object | Convention | Example |
|---|---|---|
| Tables | PascalCase, singular | `Sales`, `Customer`, `Date` |
| Columns | PascalCase | `SalesAmount`, `OrderDateKey` |
| Hidden columns (keys) | PascalCase with `Key` suffix (no space) | `CustomerKey` (hidden, used for relationship only) |
| Measures | Title Case with spaces | `[Total Sales]`, `[YTD Revenue]` |
| Calculated columns | Avoid — use measures | (Only when aggregation is impossible) |
| Display folders | Category\SubCategory | `Revenue\YTD`, `Inventory\Counts` |
| Perspectives | User-facing names | `Sales Analysis`, `Finance View` |
| Roles | `Role_GroupName` or AD group name | `Role_SalesAnalysts` |
| Partitions | `TableName_YYYYMM` or `TableName_Current` | `Sales_202401`, `Sales_Current` |
| Calculation groups | Verb phrase | `Time Intelligence`, `Currency Conversion` |

**Measure naming rules:**
- Never prefix measures with `[M]` or `_` — use Display Folders instead.
- Use consistent verb tense: `[Total ...]`, `[Average ...]`, `[Count of ...]`, `[YTD ...]`.
- Hidden measures (used only in other measures) prefix with `_`: `[_Sales Base]`.

---

## Compatibility Levels

| Feature | CL 1200 | CL 1400 | CL 1500 | CL 1600 |
|---|:---:|:---:|:---:|:---:|
| Tabular JSON metadata | ✓ | ✓ | ✓ | ✓ |
| Detail rows expressions | | ✓ | ✓ | ✓ |
| M (Power Query) partitions | | ✓ | ✓ | ✓ |
| Object-level security (OLS) | | ✓ | ✓ | ✓ |
| Many-to-many relationships (native) | | | ✓ | ✓ |
| Calculation groups | | | ✓ | ✓ |
| XMLA read/write endpoint | | | | ✓ |
| Query interleaving | | | | ✓ |

| SQL Server | Default CL | Max CL |
|---|---|---|
| 2016 | 1200 | 1200 |
| 2017 | 1400 | 1400 |
| 2019 | 1500 | 1500 |
| 2022 | 1600 | 1600 |

> CL upgrades are **irreversible** without backup/restore. Verify PBIRS supports target CL before upgrading.

```sql
SELECT [compatibility_level] FROM $System.DBSCHEMA_CATALOGS;
```

---

## Relationship Design

- Single-direction (one-to-many) is the default and safest.
- Bidirectional cross-filter: **use sparingly** — causes ambiguous filter paths and exponential query slowdown. Enable only when required for specific DAX measures.
- Many-to-many (CL 1500+): supported natively without bridge tables.
- All relationships must be active or explicitly activated in DAX with `USERELATIONSHIP()`.

### Role-Playing Dimensions

```dax
-- ShipDateKey uses inactive relationship
Sales by Ship Date = CALCULATE([Total Sales], USERELATIONSHIP(Sales[ShipDateKey], 'Calendar'[Date Key]))
```

```tmdl
relationship
    fromTable: Sales  fromColumn: ShipDateKey
    toTable: Calendar toColumn: Date Key
    isActive: false   crossFilteringBehavior: oneDirection
```

### Role-Playing Dimensions — Design Trade-off (SQLBI guidance)

Two approaches exist for handling multiple date relationships (OrderDate, ShipDate, DueDate, etc.):

| Approach | When to prefer | Trade-offs |
|---|---|---|
| **Single Calendar + USERELATIONSHIP** | 2–3 role-playing dates; few measures per alternate date | Smaller model; single source of truth for date attributes. But: every non-default date requires explicit `USERELATIONSHIP` in every measure; Calculation Groups only auto-apply to the active relationship |
| **Duplicated date tables** (one per role) | Many measures on alternate dates; Calculation Groups must apply universally | Each relationship is active → time intelligence and Calculation Groups "just work". But: N copies of Calendar; attribute changes must be replicated |

**Key inflection point** (per SQLBI — Alberto Ferrari / Marco Russo): If you use a **Time Intelligence Calculation Group**, it only evaluates against the **active** relationship. To make it work with inactive relationships, you must add explicit `USERELATIONSHIP` items per alternate date inside the calc group — which partially negates the maintenance benefit of calc groups.

**Decision rule for this org:**
1. **Default**: Single Calendar + USERELATIONSHIP (smaller model, standard SQLBI pattern)
2. **Escalate to duplicated dates** when:
   - The model has a Time Intelligence Calculation Group AND > 2 role-playing dates that need time intelligence
   - > 10 measures reference the same alternate date (maintenance burden of USERELATIONSHIP becomes high)
   - The Calendar table is small (< 20K rows) so duplication cost is negligible

**Performance difference**: Minimal. Duplicated date tables add negligible RAM (date tables are typically < 20K rows). The real cost is maintenance and correctness risk (forgetting `USERELATIONSHIP` in a new measure vs. forgetting to replicate an attribute change across copies).

**Agent behaviour**: When reviewing a model with role-playing dimensions, check whether the pattern is consistent. Flag as 🟡 MEDIUM if:
- Some measures use `USERELATIONSHIP` and others don't for the same alternate date (inconsistency)
- A Calculation Group exists but doesn't account for inactive relationships
- Duplicated date tables exist but have drifted out of sync (different columns/attributes)

> **Reference**: SQLBI — "The Definitive Guide to DAX", Chapter on Relationships; [sqlbi.com/articles/userelationship](https://sqlbi.com/articles/) for detailed guidance on role-playing patterns.

### Many-to-Many via Bridge Table (CL 1200/1400)

```dax
-- Bidirectional on Bridge only; use TREATAS to propagate filter
Sales by Account =
CALCULATE([Total Sales], TREATAS(VALUES(BridgeAccountCustomer[AccountSK]), Sales[AccountSK]))
```

---

## Partition Strategy

| Table Rows | Recommended Partition Grain |
|---|---|
| < 5M | Single partition (none needed) |
| 5M – 50M | Annual or quarterly |
| 50M – 500M | Monthly |
| > 500M | Monthly + aggregation tables |

**Naming:** `TableName_YYYY` / `TableName_YYYYQQ` / `TableName_YYYYMM` / `TableName_Current`

**Benefits:** incremental partition processing (ProcessData on changed partitions only), parallel processing, hot/cold separation.

### TMDL Partition Snippet

```tmdl
partition Sales_202401 = sql
    source =
        SELECT * FROM [SSAS].[SalesOrder]
    WHERE [Order Date Key] >= '2024-01-01' AND [Order Date Key] < '2024-02-01'
```

**Processing sequence:** Always process dimensions before facts. Historical partitions: `ProcessData` only if source changed; current partition: `ProcessFull`.

---

## Column Encoding

| Type | When Applied |
|---|---|
| **Value encoding** | Numeric columns with high cardinality — stores actual values; most efficient for measures |
| **Hash encoding** | String columns and low-cardinality numerics — stores dictionary IDs |

Force value encoding on frequently aggregated numeric columns:

```tmdl
column SalesAmount
    dataType: decimal
    encodingHint: value
```

**Cardinality guidelines:**
- Hide all SK (surrogate key) integer columns — bloat the dictionary without user value.
- Drop columns never used in reports or measures.
- String columns > 1M distinct values (e.g., transaction IDs): use as drill-through only or remove.

```dax
-- Find high-cardinality columns (DAX Studio)
EVALUATE ADDCOLUMNS(INFO.COLUMNS(), "Cardinality", COUNTROWS(VALUES(INFO.COLUMNS()[ExplicitName])))
ORDER BY [Cardinality] DESC
```

---

## Calculation Groups

Calculation groups (CL 1500+) eliminate duplicate time-intelligence measure proliferation.

**Use for:** Time intelligence (YTD/QTD/MTD/PY/rolling), currency conversion, scenario switching (Actual/Budget/Forecast).

### TMDL — Time Intelligence Calculation Group

```tmdl
calculationGroup Time Intelligence
    precedence: 10
    calculationItem YTD = CALCULATE(SELECTEDMEASURE(), DATESYTD('Calendar'[Date Key]))
    calculationItem YTD Fiscal = CALCULATE(SELECTEDMEASURE(), DATESYTD('Calendar'[Date Key], "03-31"))
    calculationItem QTD = CALCULATE(SELECTEDMEASURE(), DATESQTD('Calendar'[Date Key]))
    calculationItem MTD = CALCULATE(SELECTEDMEASURE(), DATESMTD('Calendar'[Date Key]))
    calculationItem Prior Year = CALCULATE(SELECTEDMEASURE(), SAMEPERIODLASTYEAR('Calendar'[Date Key]))
    calculationItem YOY Change =
        VAR Cur = SELECTEDMEASURE()
        VAR PY  = CALCULATE(SELECTEDMEASURE(), SAMEPERIODLASTYEAR('Calendar'[Date Key]))
        RETURN Cur - PY
    calculationItem YOY % Change =
        VAR Cur = SELECTEDMEASURE()
        VAR PY  = CALCULATE(SELECTEDMEASURE(), SAMEPERIODLASTYEAR('Calendar'[Date Key]))
        RETURN DIVIDE(Cur - PY, ABS(PY))
```

**Best practices:**
- Set `Precedence` deliberately when multiple calc groups interact — higher value evaluates first.
- Add a "No Calculation" item (`SELECTEDMEASURE()`) so users can clear the selection.
- Use `ISSELECTEDMEASURE()` guards if some measures should be excluded from a calc item.

---

## Perspectives

Perspectives reduce model complexity for targeted user groups. **Not a security feature** — data remains fully accessible; perspectives only filter the visible object list.

Create one perspective per subject area (Sales, Finance, HR). Example:

```tmdl
perspective Sales View
    table Sales
        column CustomerSK: hidden
        column ProductSK: hidden
    table Customer
    table Product
    table Date
    measure [Total Sales]
```

Hide SK columns globally, not just per-perspective.

---

## Row-Level Security (RLS)

```tmdl
role SalesRegionRole
    modelPermission: read
    tablePermission Sales = [SalesRegionCode] IN
        CALCULATETABLE(VALUES(DimSecurityUserRegion[RegionCode]),
                       DimSecurityUserRegion[UserEmail] = USERPRINCIPALNAME())
```

**Test (SSAS admin conn):**
```dax
EVALUATE CALCULATETABLE(SUMMARIZE(Sales, Sales[SalesRegionCode], "Count", COUNTROWS(Sales)), CUSTOMDATA("domain\\testuser"))
```

### Object-Level Security (OLS) — CL 1400+

```tmdl
role FinanceRole
    modelPermission: read
    tablePermission Payroll = none    -- hides table completely
```

`none` = invisible and inaccessible. OLS on a column still allows aggregation in a measure — hide that measure too if data is sensitive.

---

## Kerberos & Windows Authentication

On-premises SSAS uses **Windows Authentication exclusively**.
`Browser → PBIRS → (Kerberos double-hop: impersonates viewer) → SSAS → RLS via USERPRINCIPALNAME()`

### Kerberos Double-Hop Setup

1. **Register SPNs:**
   ```
   setspn -S HTTP/pbirs.contoso.com CONTOSO\svc-pbirs
   setspn -S MSOLAPSvc.3/ssasserver.contoso.com CONTOSO\svc-ssas
   ```
2. **Constrained delegation** on PBIRS service account (AD → Delegation): "Trust this user for delegation to specified services only" → add SSAS SPN. Use "Use any authentication protocol" for NTLM→Kerberos.
3. **Verify:** `klist tickets` on PBIRS server — look for `MSOLAPSvc.3/ssasserver.contoso.com`
4. **PBIRS connection string:** `Data Source=ssasserver.contoso.com;Initial Catalog=SalesModel;Integrated Security=SSPI;`

**Role membership:** Add AD groups (not individual users) via SSMS: `Roles → [Role] → Membership → Add`

### Org Standard: AD Groups and Role Structure

This organisation uses **Active Directory groups exclusively** for role membership — individual user accounts are never added directly to SSAS roles or PBIRS folder permissions. All access is managed through AD group membership.

**Standard SSAS role pattern (every BI project must have at least these two):**

| Role | Permission | AD Group pattern | Purpose |
|---|---|---|---|
| `{ProjectName} Consumers` | `Read` | `DL-BI-{ProjectName}-Read` | Report consumers — browser-level access |
| `{ProjectName} Authors` | `Read + Process` | `DL-BI-{ProjectName}-Readwrite` | Report authors and developers — can trigger model refresh |

- Row-Level Security (RLS) is applied within the **Consumers** role using `USERPRINCIPALNAME()`
- Authors typically bypass RLS (reviewers/developers need full data) — apply `CUSTOMDATA` or a separate admin role if needed
- Additional roles (e.g. regional data partitions, executive subsets) may be added, but the two-role baseline is mandatory
- The PBIRS service account must be a member of the Consumers role (minimum) or a dedicated service role

**TMDL role template (org standard):**
```tmdl
role '{ProjectName} Consumers'
    modelPermission: read
    // RLS table permissions go here if required

role '{ProjectName} Authors'
    modelPermission: readRefresh
```

---

## SSAS Processing Strategies

### Processing Modes

| Mode | What It Does | When to Use |
|---|---|---|
| `ProcessFull` | Drop + reload all data + recalculate | Initial load; after schema change |
| `ProcessData` | Reload data without recalculating | Partition data refresh (follow with ProcessRecalc) |
| `ProcessRecalc` | Recalculate hierarchies + relationships only | After ProcessData |
| `ProcessAdd` | Append new rows (no recalc) | Specific incremental scenarios |
| `ProcessDefrag` | Defragment VertiPaq storage | Monthly maintenance |
| `ProcessClear` | Remove all data (keep structure) | Before full reload in scripted pipelines |

**Processing order:** Always dimensions first, then facts. Use `"sequence"` (not `"parallel"`) in TMSL when order matters.

### TMSL Refresh (JSON — preferred for CL 1200+)

```json
{ "refresh": { "type": "full", "objects": [
    { "database": "SalesModel", "table": "Customer" },
    { "database": "SalesModel", "table": "Product" }
]}}
```

Single partition refresh:
```json
{ "refresh": { "type": "dataOnly", "objects": [
    { "database": "SalesModel", "table": "Sales", "partition": "Sales_202401" }
]}}
```

### SQL Server Agent Job (Nightly Processing)

```json
{ "sequence": { "operations": [
    { "refresh": { "type": "full", "objects": [
        { "database": "SalesModel", "table": "Date" },
        { "database": "SalesModel", "table": "Customer" },
        { "database": "SalesModel", "table": "Product" }
    ]}},
    { "refresh": { "type": "full", "objects": [
        { "database": "SalesModel", "table": "Sales", "partition": "Sales_Current" }
    ]}}
]}}
```

*SQL Agent step type: SQL Server Analysis Services Command; Server: `ssasserver.contoso.com`*

### AMO/TOM Processing (C#)

```csharp
// NuGet: Microsoft.AnalysisServices.Tabular.retail.amd64
using Microsoft.AnalysisServices.Tabular;
var server = new Server();
server.Connect("Data Source=ssasserver.contoso.com;Integrated Security=SSPI;");
var partition = server.Databases["SalesModel"].Model.Tables["Sales"].Partitions["Sales_202401"];
partition.RequestRefresh(RefreshType.Full);
server.Databases["SalesModel"].Model.SaveChanges();
server.Disconnect();
```

### Processing Error Check (PowerShell)

```powershell
$server = New-Object Microsoft.AnalysisServices.Server
$server.Connect("Data Source=ssasserver.contoso.com;Integrated Security=SSPI;")
$server.Databases["SalesModel"].Process([Microsoft.AnalysisServices.ProcessType]::ProcessFull)
if ($server.Databases["SalesModel"].State -ne "Processed") {
    Write-Error "SSAS processing failed. Check: $(ssas_log_root)\msmdsrv.log"
    exit 1
}
$server.Disconnect()
```

---

## XMLA / TMSL Scripting

Connect SSMS to SSAS: Server type = Analysis Services, Server name = `ssasserver.contoso.com` (or `ssasserver\TABULAR`).

### ProcessRecalc (after ProcessData)
```json
{ "refresh": { "type": "calculate", "objects": [ { "database": "SalesModel" } ] } }
```

### Synchronize Database (DR / Scale-Out)
```xml
<Synchronize xmlns="http://schemas.microsoft.com/analysisservices/2003/engine">
  <Object><DatabaseID>SalesModel</DatabaseID></Object>
  <SynchronizeSecurity>CopyAll</SynchronizeSecurity>
  <ApplyCompression>true</ApplyCompression>
  <Source>
    <ConnectionString>Data Source=ssasserver-primary.contoso.com;Integrated Security=SSPI;</ConnectionString>
    <Object><DatabaseID>SalesModel</DatabaseID></Object>
  </Source>
</Synchronize>
```

### Detach (Migration)
```xml
<Detach xmlns="http://schemas.microsoft.com/analysisservices/2003/engine">
  <Object><DatabaseID>SalesModel</DatabaseID></Object>
  <Password>OptionalEncryptionPassword</Password>
</Detach>
```

---

## VertiPaq Analyzer

Embedded in DAX Studio. Launch: Connect to SSAS → VertiPaq Analyzer ribbon → Refresh.

| Metric | Action |
|---|---|
| **Table Size (MB)** | Large → review partitioning, drop unused columns |
| **Column Cardinality** | High cardinality strings → hide or remove |
| **Dictionary Size** | High = high cardinality strings |
| **Encoding** | Numeric measures should be Value-encoded |
| **Segments** | Many with few rows = suboptimal partition sizes |

```dax
-- Table sizes
SELECT [DIMENSION_NAME] AS TableName, [TABLE_ROWS_COUNT] AS Rows,
       [TABLE_STORAGE_SIZE]/1048576.0 AS TableSizeMB
FROM $System.DISCOVER_STORAGE_TABLES WHERE [TABLE_ID] NOT LIKE 'R$*'
ORDER BY [TABLE_STORAGE_SIZE] DESC;
-- Column sizes + cardinality
SELECT [TABLE_NAME], [COLUMN_HIERARCHY_NAME], [COLUMN_ENCODING],
       [DICTIONARY_SIZE]/1048576.0 AS DictMB, [USED_SIZE]/1048576.0 AS ColMB, [TABLE_CARDINALITY]
FROM $System.DISCOVER_STORAGE_TABLE_COLUMNS WHERE [COLUMN_TYPE]='BASIC_DATA'
ORDER BY [USED_SIZE] DESC;
```

**Size reduction checklist:**
- [ ] Remove columns unused in measures, relationships, or visible field list
- [ ] Hide all SK columns
- [ ] Replace high-cardinality strings with integer codes (keep label in DW)
- [ ] Use `DATE` type for `[Date Key]` column — never `INT YYYYMMDD` or `DATETIME`
- [ ] Check for duplicate columns

---

## DAX Studio

Primary query, profiling, and diagnostic tool for on-premises SSAS Tabular.

| Feature | Access | Use Case |
|---|---|---|
| Server Timings | View → Server Timings | SE vs FE time breakdown |
| Query Plan | View → Query Plan | DAX logical/physical plan |
| VertiPaq Analyzer | Advanced → VertiPaq Analyzer | Memory analysis |
| Profiler Trace | Advanced → Profiler | SSAS trace events |
| DMV Queries | New Query → `$System.*` | Metadata + statistics |

**Server Timings:** SE CPU = VertiPaq reads (should dominate); FE CPU = DAX interpretation. FE > 20% = optimization opportunity. Use `ADDCOLUMNS(SUMMARIZE(...))` instead of nested `CALCULATE`.

**CallbackDataID** in query plan = FE calling SE row-by-row (anti-pattern). Cause: `FILTER(ALL(...), ...)` in `SUMX`.

**Profiler:** `Advanced → Profiler → Start Trace` — capture Query Begin/End, VertiPaq SE Query Begin/End.

---

## Tabular Editor 2

**Tabular Editor 2** (free/MIT) — Model editing, BPA, C# scripting, CI/CD. Executable: `TabularEditor.exe`. Connects to SSAS via AMO/TOM (Windows/SSPI auth).

### Best Practice Analyzer (BPA)

**Source:** [github.com/TabularEditor/BestPracticeRules](https://github.com/TabularEditor/BestPracticeRules)

**Install locally:** Download `BPARules-standard.json` → rename to `BPARules.json` → place in `%LocalAppData%\TabularEditor\` → restart TE2 (Tools → Best Practice Analyzer).

**For CI/CD:** commit merged rules file to repo; reference in pipeline BPA step.

#### Standard Rules — Full Reference

> **Severity:** 1=Cosmetic, 2=Minor/UX, 3=Important/Performance, 4=Very Important, 5=Critical

| Rule ID | Name | Category | Sev. |
|---|---|---|:---:|
| `DAX_COLUMNS_FULLY_QUALIFIED` | Column references fully qualified (`Table[Col]`) | DAX Expressions | 2 |
| `DAX_DIVISION_COLUMNS` | Use DIVIDE() instead of `/` | DAX Expressions | 3 |
| `DAX_MEASURES_UNQUALIFIED` | Measure references unqualified (`[Measure]`) | DAX Expressions | 2 |
| `DAX_TODO` | Revisit TODO expressions | DAX Expressions | 1 |
| `APPLY_FORMAT_STRING_COLUMNS` | Format string for visible numeric columns | Formatting | 2 |
| `APPLY_FORMAT_STRING_MEASURES` | Format string for visible numeric measures ⚠️ | Formatting | 2 |
| `DISABLE_ATTRIBUTE_HIERACHIES` | Disable attribute hierarchies on hidden columns | Metadata | 2 |
| `META_AVOID_FLOAT` | Avoid Double data type — use Decimal ⚠️ | Metadata | 3 |
| `META_SUMMARIZE_NONE` | Set SummarizeBy=None on numeric columns | Metadata | 1 |
| `LAYOUT_ADD_TO_PERSPECTIVES` | Add objects to perspectives | Model Layout | 1 |
| `LAYOUT_COLUMNS_HIERARCHIES_DF` | Organize columns/hierarchies in display folders | Model Layout | 1 |
| `LAYOUT_HIDE_FK_COLUMNS` | Hide foreign key columns ⚠️ | Model Layout | 1 |
| `LAYOUT_LOCALIZE_DF` | Translate Display Folders (cultures only) | Model Layout | 1 |
| `LAYOUT_MEASURES_DF` | Organize measures in display folders | Model Layout | 1 |
| `TRANSLATE_DESCRIPTIONS` | Translate descriptions (cultures only) | Model Layout | 1 |
| `TRANSLATE_HIDEABLE_OBJECT_NAMES` | Translate visible object names (cultures only) | Model Layout | 1 |
| `TRANSLATE_HIERARCHY_LEVEL_NAMES` | Translate hierarchy levels (cultures only) | Model Layout | 1 |
| `TRANSLATE_OTHER_NAMES` | Translate perspectives (cultures only) | Model Layout | 1 |
| `NO_CAMELCASE_COLUMNS_HIERARCHIES` | Avoid CamelCase on visible cols/hierarchies | Naming | 2 |
| `NO_CAMELCASE_MEASURES_TABLES` | Avoid CamelCase on visible measures/tables | Naming | 2 |
| `PARTITION_NAMES_SHOULD_MATCH_TABLE_NAMES` | Partition names match table names | Naming | 1 |
| `RELATIONSHIP_COLUMN_NAMES` | Relationship column names should match | Naming | 2 |
| `UPPERCASE_FIRST_LETTER_COLUMNS_HIERARCHIES` | Column/hierarchy names start uppercase | Naming | 2 |
| `UPPERCASE_FIRST_LETTER_MEASURES_TABLES` | Measure/table names start uppercase | Naming | 2 |
| `AVOID_SINGLE_ATTRIBUTE_DIMENSIONS` | Avoid single-attribute dimensions (not shared) | Performance | 2 |
| `PERF_UNUSED_COLUMNS` | Remove unused columns | Performance | 2 |
| `PERF_UNUSED_MEASURES` | Remove unused hidden measures | Performance | 1 |
| `SPECIFY_APPLICATION_NAME_IN_CONNECTION_STRING` | Specify Application Name in connection string | Performance | 1 |
| `USE_MSOLEDBSQL_PROVIDER` | Use MSOLEDBSQL (SQLNCLI/SQLOLEDB deprecated) | Performance | 2 |

> `TRANSLATE_*` rules only fire when the model has cultures defined — no action needed for single-language deployments.

#### Organization-Specific BPA Rules

Add to repository's `BPARules.json` (merge with standard file).

```json
[
  {
    "ID": "DW_SK_COLUMNS_HIDDEN",
    "Name": "Surrogate key columns should be hidden",
    "Category": "DW Standards",
    "Description": "Columns whose name ends with 'Key' but contains no spaces are DW surrogate keys (e.g. CustomerKey, OrderDateKey) and should be hidden from end users. Users should filter via relationships to the dimension table. Excludes visible dimension columns with spaces like [Date Key].",
    "Severity": 3,
    "Scope": "DataColumn, CalculatedColumn, CalculatedTableColumn",
    "Expression": "Name.EndsWith(\"Key\") && !Name.Contains(\" \") && IsVisible",
    "FixExpression": "IsHidden = true"
  },
  {
    "ID": "DW_SOURCE_COLUMNS_HIDDEN",
    "Name": "_Source* natural key columns should be hidden",
    "Category": "DW Standards",
    "Description": "Columns prefixed with '_Source' are natural key staging columns (e.g., _SourcePartyID). They should not be visible to end users.",
    "Severity": 2,
    "Scope": "DataColumn, CalculatedColumn, CalculatedTableColumn",
    "Expression": "Name.StartsWith(\"_Source\") && IsVisible",
    "FixExpression": "IsHidden = true"
  },
  {
    "ID": "DW_LINEAGE_KEY_HIDDEN",
    "Name": "LineageKey column should be hidden",
    "Category": "DW Standards",
    "Description": "LineageKey is an internal ELT batch tracking key. It must not be visible to end users.",
    "Severity": 2,
    "Scope": "DataColumn, CalculatedColumn, CalculatedTableColumn",
    "Expression": "Name == \"LineageKey\" && IsVisible",
    "FixExpression": "IsHidden = true"
  },
  {
    "ID": "DW_DEBUG_FOLDER_HIDDEN",
    "Name": "Columns in _Debug display folder should be hidden",
    "Category": "DW Standards",
    "Description": "Columns in the '_Debug' display folder (e.g., [Last Processed]) are internal debugging aids and should be hidden from the default field list.",
    "Severity": 2,
    "Scope": "DataColumn, CalculatedColumn, CalculatedTableColumn",
    "Expression": "DisplayFolder == \"_Debug\" && IsVisible",
    "FixExpression": "IsHidden = true"
  },
  {
    "ID": "DW_MEASURES_HAVE_DESCRIPTION",
    "Name": "Visible measures should have a description",
    "Category": "DW Standards",
    "Description": "All visible measures should have a description to aid end users and document allowable groupings and filter contexts.",
    "Severity": 1,
    "Scope": "Measure",
    "Expression": "IsVisible && string.IsNullOrWhiteSpace(Description)"
  },
  {
    "ID": "DW_TABLES_HAVE_DESCRIPTION",
    "Name": "Visible tables should have a description",
    "Category": "DW Standards",
    "Description": "All visible tables should have a description. Recommended format: 'Group by: Dimension1, Dimension2, ...' to guide users on allowable groupings in reports.",
    "Severity": 1,
    "Scope": "Table",
    "Expression": "IsVisible && string.IsNullOrWhiteSpace(Description)"
  },
  {
    "ID": "DW_LAST_PROCESSED_COLUMN",
    "Name": "Data tables should have a [Last Processed] calculated column",
    "Category": "DW Standards",
    "Description": "Every visible SSAS data table (non-calculated) should have a hidden calculated column named '[Last Processed]' with expression NOW(), placed in the '_Debug' display folder. This feeds the 'Last Updated Tabular' DAX calculated table used in the Debug tab.",
    "Severity": 2,
    "Scope": "Table",
    "Expression": "!IsHidden && ObjectType != ObjectType.CalculatedTable && !Columns.Any(c => c.Name == \"Last Processed\")"
  }
]
```

#### Merging Standard + Org-Specific Rules

```powershell
# Merge-BpaRules.ps1
$standard = Get-Content ".\scripts\BPARules-standard.json" | ConvertFrom-Json
$org      = Get-Content ".\scripts\BPARules-org.json"      | ConvertFrom-Json
($standard + $org) | ConvertTo-Json -Depth 10 | Set-Content ".\scripts\BPARules.json"
```

#### Running BPA in CI/CD Pipeline (ADO Server Classic)

BPA validation runs before deployment — models with severity-3+ violations never reach TEST/UAT/PROD.

```powershell
# BPA-Validate.ps1
param(
    [string]$ModelPath,        # e.g. ".\SSAS\EAO_Tabular"  (TMDL folder)
    [string]$RulesPath,        # e.g. ".\scripts\BPARules.json"
    [int]   $MinSeverity = 3
)
$te2Exe = "$(tool_tabular_editor_root)\TabularEditor.exe"
$output = & $te2Exe $ModelPath -A $RulesPath -V 2>&1
Write-Host $output
if ($LASTEXITCODE -ne 0) {
    Write-Error "##vso[task.logissue type=error]BPA validation failed — severity $MinSeverity+ violations found."
    exit 1
}
Write-Host "##vso[task.complete result=Succeeded]BPA validation passed."
```

**ADO Classic Pipeline task (add before deployment):**
```
Task Type:   PowerShell / File Path
Script Path: $(Build.SourcesDirectory)\scripts\BPA-Validate.ps1
Arguments:   -ModelPath "$(Build.SourcesDirectory)\SSAS\EAO_Tabular"
             -RulesPath "$(Build.SourcesDirectory)\scripts\BPARules.json"
             -MinSeverity 3
```

> Severity 1–2 are code review items; only severity 3+ should gate deployment.

### C# Scripting in Tabular Editor

TE2 supports C# scripts via the **Advanced Scripting** pane.

```csharp
// Hide all SK columns
foreach (var col in Model.AllColumns)
    if (col.Name.EndsWith("SK", StringComparison.OrdinalIgnoreCase)) col.IsHidden = true;

// Add Row Count audit measure to every table
foreach (var table in Model.Tables) {
    if (table.Measures.Any(m => m.Name == "Row Count")) continue;
    var m = table.AddMeasure("Row Count", $"COUNTROWS('{table.Name}')", "_Admin");
    m.FormatString = "#,##0"; m.IsHidden = true;
}
```

### Community Scripts ([github.com/TabularEditor/Scripts](https://github.com/TabularEditor/Scripts))

Paste `.csx` content into TE2 Advanced Scripting pane. Review before running — full .NET access.

| Script | What It Does |
|---|---|
| `Autogenerate SUM Measures.csx` | SUM measure per selected column; hides source column |
| `Create countrows measures.csx` | COUNTROWS measure per table |
| `Format All Measures.csx` | Sets format string on all visible measures |
| `Hide columns on the many side of a relationship.csx` | Hides all FK columns (`LAYOUT_HIDE_FK_COLUMNS`) |
| `Move All Columns to a DisplayFolder.csx` | Moves selected columns to a folder |
| `Clean object names.csx` | snake_case / CamelCase → Title Case |
| `CreateExplicitMeasures.csx` | Explicit measures for all numeric columns |
| `Create Time Intelligence Measures Using Calculation Groups.csx` | YTD/MTD/PY calc group items (CL 1500+) |
| `tmdl_slimmer.csx` | Removes TMDL defaults to reduce git diff noise |
| `bim_slimmer.csx` | Same for `.bim` format |

**New model setup sequence:** (1) `Hide columns on the many side...` → (2) `Autogenerate SUM Measures` → (3) `Format All Measures` → (4) `tmdl_slimmer`

---

### CI/CD Pipeline with Tabular Editor 2 CLI

```powershell
# Build step: validate model with BPA (fail if any severity 3+ issues)
TabularEditor.exe ".\SSAS\EAO_Tabular" -A ".\scripts\BPARules.json" -V

# Deploy step: deploy to SSAS (overwrite existing, retain partitions, deploy roles)
TabularEditor.exe ".\SSAS\EAO_Tabular" `
    -D "ssasserver\TABULAR" "EAO_Tabular_TEST" `
    -O -R -P
```

> See `devops-deployment-patterns.md` Section 4 for the full deployment pipeline configuration,
> and Section 6 + 10 for triggering SSAS processing via `runDbaAgentJob.ps1`.

---

## ALM Toolkit

ALM Toolkit (Christian Wade, Microsoft) — schema comparison and deployment tool for SSAS Tabular. Recommended over SSDT for change-controlled production deployments.

| Aspect | SSDT Deploy | ALM Toolkit |
|---|---|---|
| Deployment type | Full overwrite | Delta/diff-based |
| Partition preservation | ❌ Destroys all | ✓ Preserves |
| Schema diff visibility | ❌ None | ✓ Visual diff |
| Selective object deploy | ❌ All or nothing | ✓ Choose objects |

**Workflow:** Source (`.bim` or DEV) → Target (PROD) → Compare → uncheck objects not to update → Update (executes minimal TMSL script).

### ALM Toolkit CLI

```powershell
AlmToolkit.exe `
    -s ".\Model.bim" `
    -t "ssasserver.contoso.com\SalesModel" `
    -o deploy `
    -skipPartitions `
    -skipRoles:false
```

---

## Model Deployment

### Deployment Checklist
- [ ] Run BPA in Tabular Editor — resolve all severity 3+ issues
- [ ] Verify CL matches target SSAS instance (don't deploy CL 1500 to SQL 2017)
- [ ] Compare with ALM Toolkit — review diff before deploying
- [ ] Deploy DEV → UAT → PROD in sequence; never directly to PROD from local
- [ ] Run smoke tests post-deployment
- [ ] Trigger processing via SQL Server Agent job or TMSL script
- [ ] Verify PBIRS data sources after any server migration

### SSDT Deployment (Development Use Only)
```
SSDT → Deploy → Server: ssasserver-dev.contoso.com
  - Processing Option: Do Not Process
  - Transactional Deployment: Yes
  - Query Mode: In-Memory
```

### Smoke Tests Post-Deployment

```dax
-- Row counts
EVALUATE { ( "Sales", COUNTROWS(Sales) ), ( "Customer", COUNTROWS(Customer) ), ( "Date", COUNTROWS('Date') ) }
-- Key measure
EVALUATE { [Total Sales] }
-- RLS check
EVALUATE CALCULATETABLE({ COUNTROWS(Sales) }, CUSTOMDATA("CONTOSO\\testuser"))
```

---

## Backup and Restore

```json
{ "backup": { "database": "SalesModel", "file": "\\\\backupserver\\SSASBackups\\SalesModel_{@date}.abf",
              "allowOverwrite": true, "applyCompression": true, "password": "$(BackupPassword)" } }
```

*SQL Agent step type: SQL Server Analysis Services Command*

| Backup Type | Frequency | Retention |
|---|---|---|
| Post-processing | After nightly ETL | 7 days |
| Pre-deployment | Before every deployment | 30 days |
| Weekly full | Sunday | 90 days |

**Restore:**
```xml
<Restore xmlns="http://schemas.microsoft.com/analysisservices/2003/engine">
  <File>\\backupserver\SSASBackups\SalesModel_20240115.abf</File>
  <DatabaseName>SalesModel_Restored</DatabaseName><AllowOverwrite>true</AllowOverwrite>
  <Password>StrongEncryptionPassword123!</Password>
</Restore>
```

**Automated backup + purge (PowerShell):**
```powershell
$backupPath = "\\backupserver\SSASBackups"
$backupFile = "$backupPath\SalesModel_$(Get-Date -Format 'yyyyMMdd_HHmm').abf"
Invoke-ASCmd -Server "ssasserver.contoso.com" -Query (ConvertTo-Json @{backup=@{database="SalesModel";file=$backupFile;allowOverwrite=$true;applyCompression=$true}})
Get-ChildItem $backupPath -Filter "SalesModel_*.abf" | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } | Remove-Item -Force
```

**DR:** Backup `.abf` offsite; source-control model; script SQL Agent jobs; test restore quarterly.

---

## Power BI Report Server Live Connection Constraints

### PBIRS Live Connection Capabilities

| Capability | Available? |
|---|---|
| Use all SSAS model measures | ✓ Yes |
| Report-level filters, drillthrough, bookmarks | ✓ Yes |
| Use perspectives | ✓ Yes |
| Conditional formatting (on model measures) | ✓ Yes |
| Create measures / calculated columns / tables in report | ❌ No — must be in SSAS model |
| Composite models (live + imported) | ❌ No |
| What-if parameters | ❌ No — requires import mode |
| Q&A visual | ❌ Limited — only with model Q&A synonyms |
| Report-level RLS | ❌ No — RLS must be in SSAS roles |
| Multiple SSAS sources in one report | ❌ No |
| DirectQuery to SQL + Live SSAS | ❌ No |

### PBIRS ↔ SSAS Version Compatibility Matrix

| PBIRS Version | Max CL |
|---|---|
| PBIRS 2017 | 1200 |
| PBIRS 2019 | 1400 |
| PBIRS 2020 | 1500 |
| PBIRS 2022 | 1500 |
| PBIRS 2023 | 1600 |

PBIRS must be **equal to or newer** than the SQL Server version hosting SSAS.

### PBIRS Data Source Configuration

```
Data Source Type: Analysis Services
Connection string: Data Source=ssasserver.contoso.com;Initial Catalog=SalesModel
Authentication: Windows integrated security (Kerberos for live connection with RLS)
Impersonation: Impersonate the Windows user viewing the report (required for RLS)
```

---

## DMV Reference Queries

All `$System.*` DMVs work via DAX Studio or SSMS (Analysis Services connection).

```dax
-- Tables
SELECT [TableName], [TableCount] AS Rows FROM $System.TMSCHEMA_TABLES;

-- Measures
SELECT [TableName], [MeasureName], [Expression], [DisplayFolder]
FROM $System.TMSCHEMA_MEASURES ORDER BY [TableName], [MeasureName];

-- Columns (encoding + cardinality)
SELECT [TABLE_NAME], [COLUMN_HIERARCHY_NAME], [DATA_TYPE], [COLUMN_ENCODING],
       [TABLE_CARDINALITY] AS Cardinality
FROM $System.DISCOVER_STORAGE_TABLE_COLUMNS WHERE [COLUMN_TYPE] = 'BASIC_DATA'
ORDER BY [TABLE_CARDINALITY] DESC;

-- Relationships
SELECT [FromTableName], [FromColumnName], [ToTableName], [ToColumnName],
       [Active], [CrossFilteringBehavior]
FROM $System.TMSCHEMA_RELATIONSHIPS;

-- Role members
SELECT [RoleName], [MemberName], [MemberType] FROM $System.TMSCHEMA_ROLE_MEMBERSHIPS;

-- Partition processing state
SELECT [TableName], [PartitionName], [State] AS ProcessingState, [ModifiedTime]
FROM $System.TMSCHEMA_PARTITIONS ORDER BY [TableName], [PartitionName];

-- Memory usage (top 20 tables)
SELECT TOP 20 [DIMENSION_NAME] AS TableName, [TABLE_ROWS_COUNT] AS Rows,
       [TABLE_STORAGE_SIZE] / 1048576.0 AS TableSizeMB
FROM $System.DISCOVER_STORAGE_TABLES WHERE [TABLE_ID] NOT LIKE 'R$*'
ORDER BY [TABLE_STORAGE_SIZE] DESC;

-- Server properties
SELECT [PROPERTY_NAME], [PROPERTY_VALUE] FROM $System.DISCOVER_PROPERTIES
WHERE [PROPERTY_NAME] IN ('ProductVersion','DefaultCompatibilityLevel','MemoryLimit','LowMemoryLimit','TotalMemoryUsage');
```

---

## Common Review Findings

| # | Finding | Severity | Correction |
|---|---|---|---|
| 1 | Surrogate key (`{Entity}Key`) columns visible to users | Medium | Set `IsHidden = true` on all `{Entity}Key` columns (no-space names ending in `Key`); use the `DW_SK_COLUMNS_HIDDEN` BPA rule |
| 2 | Measures without format strings | High | Add `FormatString` to every measure; use `"#,##0.00"` for currency |
| 3 | Calculated columns on large fact tables | High | Replace with DAX measures; calculated columns bloat VertiPaq |
| 4 | Bidirectional relationships on all tables | High | Only enable bidirectional where explicitly required; document reason |
| 5 | No display folders on measures | Medium | Group measures into folders (e.g., `Revenue`, `Costs`, `KPIs`) |
| 6 | RLS not tested before production deploy | Critical | Always test with `CUSTOMDATA()` / `USERPRINCIPALNAME()` before go-live |
| 7 | SSAS not backed up before deployment | Critical | Always take `.abf` backup before deploying model changes |
| 8 | Processing sequence: facts before dimensions | High | Always process dimensions first; use `"sequence"` in TMSL |
| 9 | Duplicate time-intelligence measures per base measure | High | Replace with calculation groups (CL 1500+) |
| 10 | Date table not marked as Date Table in SSAS | High | Right-click table → Mark as Date Table → select DATE column |
| 11 | PBIRS report using new measures not in model | High | PBIRS live connection does not support report-layer measures |
| 12 | No partitioning on large (>10M row) fact tables | High | Add monthly partitions; enables incremental processing |
| 13 | Model deployed directly from SSDT to production | Medium | Use ALM Toolkit for production deployments |
| 14 | Kerberos double-hop not configured for PBIRS | Critical | Configure constrained delegation (see Kerberos section) |
| 15 | Compatibility level not matched to PBIRS version | High | Verify PBIRS supports target CL before upgrading |
| 16 | No BPA rules enforced in CI/CD | Medium | Add Tabular Editor BPA step to deployment pipeline |
| 17 | AMO/TOM version mismatch in processing scripts | Medium | Pin NuGet package to same major version as SSAS instance |
| 18 | Model has no perspectives | Low | Add at least one perspective per subject area |
| 19 | `NULL` FK values in source DW tables | High | Use `'1753-01-01'` (DATE type) as the unknown-date sentinel; `NULL` breaks SSAS relationship integrity. Fact rows with `NULL` dates should resolve to the `1753-01-01` sentinel row in `Dimension.Calendar`, which appears as a VertiPaq blank row in slicers — document this as expected behaviour |
| 20 | SSAS service account not in local Administrators | Low | SSAS service account needs `Log on as a service` and access to backup paths |


---

## SSAS Schema View Contract

### Purpose
The `SSAS` schema in the DW database contains SQL views only. These views are the sole source of data for SSAS Tabular table partitions. No SSAS partition should query a `Dimension`, `Fact`, or `Staging` table directly.

### Naming convention
- View name matches the SSAS table name exactly: `SSAS.Calendar`, `SSAS.Customer`, `SSAS.SalesTransaction`
- No prefixes (not `vw_Calendar`, not `v_Calendar`)

### Column alias rules (enforced)
1. **Every column must have an alias** — no bare column references
2. **Aliases use Title Case with spaces** — this becomes the SSAS attribute name visible to report users
3. **Surrogate key alias**: `{EntityName} Key` (with space) — e.g. `CustomerKey AS [Customer Key]`
4. **Natural key alias**: `{Entity} Source ID` — e.g. `_SourceCustomerID AS [Customer Source ID]`
5. **Boolean flags**: readable phrase — e.g. `IsActive AS [Is Active]`, `IsHoliday AS [Is Holiday]`
6. **Date columns**: include unit if ambiguous — e.g. `CreatedDate AS [Created Date]`, not just `[Created]`

### No business logic in SSAS views
SSAS views must be pure projections — no CASE expressions, no computed columns, no joins. All transformations belong in the dimension/fact load SPs. If a column is needed in SSAS but doesn't exist in the underlying table, add it to the DW table and load SP first.

### Surrogate and natural key exposure
- Surrogate key (`{EntityName}Key`) — **always include, alias as `[{Entity} Key]`** — required for SSAS relationships
- Natural key (`_Source{OriginalName}`) — **include for traceability, alias as `[{Entity} Source {OriginalName}]`** — hide in SSAS model (used for drill-through only)
- Both must be present; hiding happens in the SSAS model, not by omitting from the view

### Example view
```sql
CREATE VIEW [SSAS].[Customer]
AS
SELECT
    CustomerKey             AS [Customer Key],
    _SourceCustomerID       AS [Customer Source ID],
    FullName                AS [Customer Name],
    EmailAddress            AS [Email Address],
    Region                  AS [Region],
    Country                 AS [Country],
    PostCode                AS [Post Code],
    IsActive                AS [Is Active],
    CreatedDate             AS [Created Date]
FROM [Dimension].[Customer];
GO
```

### Partition configuration in SSAS
Each SSAS table has a single partition pointing to its SSAS view:
- Data source: the DW database connection (named `{ProjectName}DW` in SSAS)
- Query: `SELECT * FROM [SSAS].[{TableName}]`
- Partition name: `{TableName}_Full` for full-load tables; `{TableName}_{Year}` for year-partitioned facts

### Review checklist (Mode A — DW Schema Review)
When reviewing SSAS views, check:

| Check | Severity if failed |
|---|---|
| Every SSAS table has a corresponding `SSAS` schema view | 🔴 CRITICAL |
| All column aliases use Title Case with spaces | 🟠 HIGH |
| No business logic (CASE, computed expressions) in view | 🟠 HIGH |
| Surrogate key included and aliased correctly | 🔴 CRITICAL |
| Natural key included (for traceability) | 🟡 MEDIUM |
| No direct partition query on Dimension/Fact table | 🟠 HIGH |
