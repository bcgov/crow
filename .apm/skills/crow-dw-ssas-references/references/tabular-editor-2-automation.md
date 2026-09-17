<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# Tabular Editor 2 Automation Reference

Authoritative reference for **Tabular Editor 2 (TE2)** CLI usage, C# scripting, and the organisation Best Practice Analyzer (BPA) rule set. Used by Copilot for Mode I (SSAS Tabular Model Scaffold), Mode B (SSAS Model Review), Mode L (DAX Measure Generation), and Mode N (Full Orchestrated Build).

## Hard Constraints (read first)

- **Tabular Editor 2 ONLY** — the free version. Tabular Editor 3 is **not** available in this organisation. Never reference TE3 or any TE3-only API, feature, script editor, or pricing tier.
- **TE2 executable path:** `$(tool_tabular_editor_root)\TabularEditor.exe`
- **SSAS Tabular ONLY** — never generate MDX, Multidimensional, MOLAP, or ROLAP artefacts.
- **ADO Classic pipelines only** — never produce YAML pipeline definitions.
- TE2 runs on **.NET Framework 4.x** — no `async`/`await`, no LINQ APIs added in .NET 5+, no `record` types, no nullable reference type syntax.

## Org Naming Conventions (recap, used by scripts and BPA rules)

- Schemas: `Dimension`, `Fact`, `Staging`, `Internal`, `SSAS` (views), `Security`, `Snapshots`
- No table prefixes — `Dimension.Customer`, not `DimCustomer`
- Surrogate key column: `{EntityName}Key`; natural key: `_Source{OriginalName}`
- Date dimension: `Dimension.Calendar` → SSAS table named `Calendar`
- SSAS views live in the `SSAS` schema; column aliases are **Title Case With Spaces** and are the source of the column names in the model
- Environments: `DEV`, `TEST`, `UAT`, `PROD`, `SUPPORT`
- Security: AD groups only; two roles per project: `{Name} Consumers` (Read) and `{Name} Authors` (Read + Process)
- Every measure must have: `Description` (with `Valid groupings:` and `Notes:`), `FormatString`, `DisplayFolder`
- Every visible column must have a Title Case name with spaces

---

## 1. TE2 CLI Reference

General invocation:

```cmd
TabularEditor.exe <model-or-bim> [script] [deploy-options] [bpa-options]
```

The first positional argument is the **source model**, which can be either:

- A `.bim` file: `"path\to\Model.bim"`
- A TMDL/folder-serialised model: `"path\to\tmdl-folder"`

### Flag reference

| Flag | Argument | Purpose |
|------|----------|---------|
| `-S` | `"script.cs"` | Run a C# script against the loaded model before any deploy/save step. |
| `-B` | `"output.bim"` | Build/save the model to a single `.bim` file (TMDL → `.bim` conversion). |
| `-D` | `"provider=MSOLAP;Data Source=server\instance;"` `"CatalogName"` | Deploy the model to an SSAS Tabular instance. Two arguments: the connection string, then the catalog (database) name. |
| `-O` | _(none)_ | **O**verwrite the existing database on deploy. |
| `-C` | _(none)_ | Replace roles and their member assignments on deploy (role **C**hanges). |
| `-V` | _(none)_ | **V**alidate BPA rules against the model. Exits non-zero if violations occur **only when combined with `-A`**. |
| `-A` | _(none)_ | Treat BPA violations **A**s errors — drives the non-zero exit code that fails the ADO task. |
| `-R` | _(none)_ | **R**eport BPA results to the console (stdout). |
| `-E` | _(none)_ | Allow d**E**ploy even when BPA warnings exist. Use only after `-V` has run cleanly in the build. |
| `-M` | _(none)_ | Deploy **M**etadata only — no data processing. Org default for release pipelines (processing is a separate scheduled job). |
| `-T` | `"trace-file.txt"` | Write **T**race output to file. |
| `-X` | `"exclude-file.txt"` | E**X**clude listed objects from deployment. |
| `-P` | `"password"` | Model **P**assword (only if the `.bim` is encrypted). |

### Exact command — ADO **build** pipeline (BPA check)

```cmd
TabularEditor.exe "$(Build.SourcesDirectory)\SSAS\Model.bim" -V -A -R
```

### Exact command — ADO **release** pipeline (deploy)

```cmd
TabularEditor.exe "$(artifact_dir)\SSAS\Model.bim" -S "$(tool_tabular_editor_scripts_path)\SetConnectionStringFromEnv.cs" -D "Provider=MSOLAP;Data Source=$(sass_server)\$(ssas_db);" "$(ssas_catalog)" -O -C -V -E -R -M
```

Flag walk-through for the release command:
- `-S …\SetConnectionStringFromEnv.cs` — rewrite partition connection strings to the env-specific value before deploying.
- `-D "…MSOLAP…" "$(ssas_catalog)"` — deploy target server + catalog.
- `-O` — overwrite the existing catalog.
- `-C` — refresh roles/permissions to whatever is in the `.bim`.
- `-V -E -R` — run BPA, but allow warnings through (build pipeline already gated on `-A`), echo results to logs.
- `-M` — metadata only; data is processed separately.

---

## 2. TMDL vs BIM Workflow

- **Development:** developers work in the TMDL folder format via TE2 _Save As Folder_. This is what is committed to the repo (clean diffs per object).
- **Build pipeline:** converts the TMDL folder to a single `.bim` using the `-B` flag, then runs BPA against the `.bim`. The `.bim` is the **only** deployable artefact published to the drop.
- **Release pipeline:** deploys from the `.bim` artefact exclusively — never deploys TMDL directly.

Why: the `.bim` is a single file with a deterministic hash, making artefact comparison and rollback trivial. TMDL is a folder of many files and is easier to corrupt or partially copy in transit.

Build conversion example:

```cmd
TabularEditor.exe "$(Build.SourcesDirectory)\SSAS" -B "$(Build.ArtifactStagingDirectory)\SSAS\Model.bim" -V -A -R
```

---

## 3. C# Script Library

All scripts target **TE2 / .NET 4.x**. Save them under the path resolved by `$(tool_tabular_editor_scripts_path)` (org-standard variable) so the release pipeline can locate them by relative name.

### 3a. `SetConnectionStringFromEnv.cs`

Used in the release pipeline to inject the environment-specific connection string into every `ProviderDataSource`. The env variable name follows the pattern `{DataSourceName}ConnectionString` (e.g. `CTS_EAO_DWConnectionString`).

```csharp
// SetConnectionStringFromEnv.cs
// Replace all partition data source connection strings with the env variable value.
// Called via: TabularEditor.exe Model.bim -S SetConnectionStringFromEnv.cs -D ...
var envVarName = "{DataSourceName}ConnectionString"; // e.g. CTS_EAO_DWConnectionString
var connString = Environment.GetEnvironmentVariable(envVarName);
if (string.IsNullOrEmpty(connString))
    throw new Exception(envVarName + " environment variable not set");

foreach (var ds in Model.DataSources.OfType<ProviderDataSource>())
{
    ds.ConnectionString = connString;
}
```

Replace `{DataSourceName}` with the actual ADO release variable name when scaffolding for a new project.

### 3b. `BulkAddMeasures.cs`

Scaffolds multiple measures on a target table with org-standard properties — used during Mode L.

```csharp
// BulkAddMeasures.cs
// Add measures to the specified table with org-standard properties.
var targetTable = Model.Tables["Fact Table Name"]; // replace with actual table

var measures = new[] {
    new {
        Name   = "Total Amount",
        Dax    = "SUM([Amount Column])",
        Format = "#,##0.00",
        Folder = "Business Area",
        Desc   = "Sum of Amount. Valid groupings: All dimensions. Notes: Additive."
    }
    // Add further measures here following the same shape.
};

foreach (var m in measures)
{
    var measure = targetTable.AddMeasure(m.Name, m.Dax);
    measure.FormatString  = m.Format;
    measure.DisplayFolder = m.Folder;
    measure.Description   = m.Desc;
}
```

### 3c. `ApplyTitleCaseAliases.cs`

Validation script — flags visible columns whose name does not look like Title Case With Spaces (sourced from the SSAS schema view aliases).

```csharp
// ApplyTitleCaseAliases.cs
// Validates that all visible columns have a Name matching Title Case with spaces.
// Reports non-conforming columns as warnings (does not mutate the model).
foreach (var col in Model.AllColumns.Where(c => !c.IsHidden))
{
    if (col.Name.Contains("_") || col.Name == col.Name.ToUpper())
        Warning("Column '" + col.Table.Name + "'.'" + col.Name +
                "' may not follow Title Case naming convention");
}
```

### 3d. `HideKeyColumns.cs`

Hide all surrogate key columns (`{Entity}Key` pattern) and `_Source*` natural key columns — the SSAS model exposes only business attributes; keys live behind the scenes for relationships only. The `!col.Name.Contains(" ")` guard ensures visible dimension attributes such as `[Date Key]` (Calendar) are not accidentally hidden.

```csharp
// HideKeyColumns.cs
foreach (var col in Model.AllColumns)
{
    // Hide {Entity}Key surrogate keys — no spaces, ends with "Key"
    // Guard: !Contains(" ") prevents hiding 'Calendar'[Date Key] and similar
    if (col.Name.EndsWith("Key") && !col.Name.Contains(" "))
        col.IsHidden = true;
    // Hide _Source* natural key columns (source system IDs not surfaced in reports)
    else if (col.Name.StartsWith("_Source"))
        col.IsHidden = true;
}
```

### 3e. `SetDisplayFolders.cs`

Applies display folder groupings to measures based on naming-prefix conventions.

```csharp
// SetDisplayFolders.cs
// Apply display folders to measures based on prefix conventions.
foreach (var measure in Model.AllMeasures)
{
    if (measure.Name.StartsWith("_Debug"))
        measure.DisplayFolder = "_Debug";
    else if (measure.Name.StartsWith("YTD "))
        measure.DisplayFolder = measure.DisplayFolder + "\\Time Intelligence";
    else if (measure.Name.StartsWith("Prior Year "))
        measure.DisplayFolder = measure.DisplayFolder + "\\Time Intelligence";
}
```

---

## 4. Org BPA Rule Set (`BPARules.json`)

Drop this file at the TE2 default rule location (`%LocalAppData%\TabularEditor\BPARules.json` on developer machines, or under `$(tool_tabular_editor_scripts_path)` on the build agent), or load it explicitly. TE2 evaluates these rules when `-V` is supplied.

Severity values: `1` = warning, `2` = error. Combined with `-A` on the CLI, any matched rule causes a non-zero exit.

```json
[
  {
    "ID": "ORG_MEASURE_HAS_DESCRIPTION",
    "Name": "Every measure must have a Description",
    "Category": "Org Standards",
    "Description": "Measures must have a non-empty Description including 'Valid groupings:' and 'Notes:' sections.",
    "Severity": 2,
    "Scope": "Measure",
    "Expression": "string.IsNullOrWhiteSpace(Description)"
  },
  {
    "ID": "ORG_MEASURE_HAS_DISPLAYFOLDER",
    "Name": "Every measure must have a DisplayFolder",
    "Category": "Org Standards",
    "Description": "Measures must be organised into a DisplayFolder.",
    "Severity": 2,
    "Scope": "Measure",
    "Expression": "string.IsNullOrWhiteSpace(DisplayFolder)"
  },
  {
    "ID": "ORG_MEASURE_HAS_FORMATSTRING",
    "Name": "Every measure must have a FormatString",
    "Category": "Org Standards",
    "Description": "Measures must declare an explicit FormatString.",
    "Severity": 2,
    "Scope": "Measure",
    "Expression": "string.IsNullOrWhiteSpace(FormatString)"
  },
  {
    "ID": "ORG_MEASURE_NO_RAW_DIVISION",
    "Name": "Measures must use DIVIDE() instead of '/'",
    "Category": "Org Standards",
    "Description": "Division by '/' does not guard against divide-by-zero; use DIVIDE().",
    "Severity": 2,
    "Scope": "Measure",
    "Expression": "Expression != null && System.Text.RegularExpressions.Regex.IsMatch(Expression, \"(?<![/*])/(?![/*])\")"
  },
  {
    "ID": "ORG_COLUMN_TITLECASE",
    "Name": "Visible columns must use Title Case with spaces",
    "Category": "Org Standards",
    "Description": "Visible column names must not contain underscores (except _Source* natural keys, which should be hidden) and must not be ALL CAPS.",
    "Severity": 1,
    "Scope": "DataColumn CalculatedColumn",
    "Expression": "!IsHidden && (Name.Contains(\"_\") || Name == Name.ToUpper())"
  },
  {
    "ID": "ORG_NO_BIDIRECTIONAL_RELATIONSHIPS",
    "Name": "No bidirectional relationships without justification",
    "Category": "Org Standards",
    "Description": "Bidirectional cross-filtering is prohibited unless explicitly justified by the data architect.",
    "Severity": 1,
    "Scope": "Relationship",
    "Expression": "CrossFilteringBehavior == TOM.CrossFilteringBehavior.BothDirections"
  },
  {
    "ID": "ORG_MODEL_HAS_ROLES",
    "Name": "Model must have at least one role",
    "Category": "Org Standards",
    "Description": "Every model must define at least one security role.",
    "Severity": 2,
    "Scope": "Model",
    "Expression": "Roles.Count == 0"
  },
  {
    "ID": "ORG_ROLE_NAMING",
    "Name": "Role names must end in 'Consumers' or 'Authors'",
    "Category": "Org Standards",
    "Description": "Roles must follow the pattern '{Name} Consumers' or '{Name} Authors'.",
    "Severity": 1,
    "Scope": "ModelRole",
    "Expression": "!Name.EndsWith(\" Consumers\") && !Name.EndsWith(\" Authors\")"
  },
  {
    "ID": "ORG_NO_IMPLICIT_MEASURES",
    "Name": "No implicit auto-measures",
    "Category": "Org Standards",
    "Description": "Columns must not expose implicit summarisation; all aggregations must be explicit measures.",
    "Severity": 2,
    "Scope": "DataColumn",
    "Expression": "SummarizeBy != TOM.AggregateFunction.None"
  },
  {
    "ID": "ORG_CALENDAR_IS_DATE_TABLE",
    "Name": "Calendar table must be marked as date table",
    "Category": "Org Standards",
    "Description": "The 'Calendar' table must be flagged as a date table with a Date column.",
    "Severity": 2,
    "Scope": "Table",
    "Expression": "Name == \"Calendar\" && !DataCategory.Equals(\"Time\", StringComparison.OrdinalIgnoreCase)"
  }
]
```

### Notes on the rules

- The `ORG_MEASURE_NO_RAW_DIVISION` regex `(?<![/*])/(?![/*])` deliberately ignores `//` line comments and `/*…*/` block comments while still catching genuine division operators.
- `ORG_COLUMN_TITLECASE` only fires on visible columns — `_Source*` natural keys are expected to be hidden and so will not trip the rule.
- `ORG_NO_BIDIRECTIONAL_RELATIONSHIPS` is severity `1` (warning) so that a documented exception can pass the release pipeline (which uses `-E`) while still failing the build (which uses `-A`).

---

## 5. BPA in the ADO Build Pipeline

- BPA runs as part of the **build**, not the release. Catching standards violations before the `.bim` artefact is produced prevents bad metadata ever reaching a deployable drop.
- The rules file is loaded automatically when present at the TE2 default location (`%LocalAppData%\TabularEditor\BPARules.json`) on the build agent. The `-R` flag echoes results to the console; it does **not** specify the rules file path.
- Exit-code behaviour: `-A` causes any BPA rule match to produce exit code `1`, which fails the ADO Command Line task.

### Build task — ADO Classic pipeline format

```
Task type:       Command Line
Display name:    BPA Check — SSAS Tabular Model
Tool:            $(tool_tabular_editor)
Arguments:       "$(Build.SourcesDirectory)\SSAS" -V -A -R
Working folder:  $(System.DefaultWorkingDirectory)
Fail on stderr:  true
```

Pair this with a preceding Command Line task that performs the TMDL → `.bim` build:

```
Task type:       Command Line
Display name:    Build BIM from TMDL
Tool:            $(tool_tabular_editor)
Arguments:       "$(Build.SourcesDirectory)\SSAS" -B "$(Build.ArtifactStagingDirectory)\SSAS\Model.bim"
Working folder:  $(System.DefaultWorkingDirectory)
Fail on stderr:  true
```

---

## 6. Common TE2 Scripting Pitfalls

- **.NET 4.x only.** No `async`/`await`, no `record` types, no nullable reference types, no LINQ APIs introduced in .NET 5+ (`Chunk`, `MaxBy`, `MinBy`, etc.). Stick to LINQ that exists in .NET Framework 4.7.2.
- **DataSource types.** TE2 supports `ProviderDataSource` (legacy / MSOLAP / OLEDB) and `StructuredDataSource` (Power Query / M). The org uses `ProviderDataSource` exclusively — scripts should filter with `.OfType<ProviderDataSource>()` as shown in `SetConnectionStringFromEnv.cs`.
- **Error surfaces.** Script exceptions appear in the TE2 console and propagate as a non-zero exit when run via `-S`. Always throw with a meaningful message (include the missing env var name, the table being processed, etc.) so the ADO log is self-diagnosing.
- **Script paths in pipelines.** When using `-S` in the build or release pipeline, supply either an absolute path or a path relative to `$(tool_tabular_editor_scripts_path)`. Do not rely on the current working directory of the agent.
- **`Warning(...)` vs `Info(...)`.** Both write to the script output; only an unhandled exception sets a non-zero exit. If a script must fail the build, `throw new Exception(...)` — do not rely on `Warning(...)` alone.
- **Avoid TE3-only APIs.** Anything documented under "Tabular Editor 3 scripting" (e.g. the script debugger, custom actions UI, advanced macros) is unavailable. If a TE3 sample is referenced online, validate every API call against the TE2 scripting docs before committing it.
