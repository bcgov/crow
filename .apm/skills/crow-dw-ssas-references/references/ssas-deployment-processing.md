<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# SSAS Tabular Deployment & Processing Reference

Authoritative reference for SSAS **Tabular** model deployment and processing in this organisation. Used by Mode B (SSAS Tabular Model Review), Mode I (SSAS Tabular Model Scaffold), Mode G (DevOps Deployment Review), Mode M (ADO Pipeline Config), and Mode N (Full Orchestrated Build).

> **Scope:** SSAS **Tabular** only. This organisation does not use Multidimensional, MDX, MOLAP, or ROLAP. All deployment uses **Tabular Editor 2** (free edition) and **Azure DevOps Server Classic** (UI) pipelines — never YAML, never Tabular Editor 3.

## 1. Deployment overview

Deployment in this organisation follows a strict pattern:

- **Tool:** Tabular Editor 2 CLI (`TabularEditor.exe`). Never XMLA scripted deploy via SSMS, never the SSDT "Deploy" command, never Analysis Services Deployment Wizard from a pipeline.
- **Path (all build/release agents):** `$(tool_tabular_editor_root)\TabularEditor.exe` — exposed as the ADO variable `$(tool_tabular_editor)`.
- **Source artifact:** the `.bim` file produced by the build pipeline. The release pipeline **never deploys TMDL directly** — TMDL is the authoring format in source control; the build pipeline converts TMDL → `.bim` and publishes it as the artifact.
- **Roles & permissions:** deployed by the `-C` flag on the same TE2 command — there is no separate role deployment step.
- **Processing:** **not** part of the SSAS deploy step. Processing is performed by a SQL Agent job triggered later in the release pipeline (see Section 5).

Pipeline phases (Classic release definition):

| Phase | Purpose | Tooling |
|---|---|---|
| 1 | Build artifact (TMDL → `.bim`) | Tabular Editor 2 CLI in the **build** pipeline |
| 2 | DW SQL deploy (schemas, SPs, ELT) | SQL scripts |
| 3 | SSAS deploy (metadata + roles) | Tabular Editor 2 CLI `-M -C` |
| 4 | Trigger SQL Agent job (ELT + SSAS Process Full) | `runDbaAgentJob.ps1` |
| 5 | Smoke tests | DMV queries (Section 8) |

## 2. Tabular Editor 2 deploy command (complete reference)

The exact deploy command used in the release pipeline:

```cmd
"$(tool_tabular_editor)" "$(artifact_dir)\SSAS\Model.bim" ^
  -S "$(tool_tabular_editor_scripts_path)\SetConnectionStringFromEnv.cs" ^
  -D "Provider=MSOLAP;Data Source=$(sass_server)\$(ssas_db);" "$(ssas_catalog)" ^
  -O -C -V -E -R -M
```

### Flag reference

| Flag | Argument(s) | Meaning |
|---|---|---|
| `-S` | `script.cs` | Run a C# script against the in-memory model **before** deploy. Used here to inject the environment-specific connection string. |
| `-D` | `"connstr" "catalog"` | Deploy to the SSAS instance described by `connstr`, creating/overwriting database `catalog`. |
| `-O` |  | **Overwrite** existing catalog if present. Without this, deploy fails when the database already exists. |
| `-C` |  | Deploy **roles and role membership** in addition to model metadata. **Critical** — without `-C`, AD group → role mappings are not deployed and consumers lose access. |
| `-V` |  | Run **BPA** (Best Practice Analyzer) validation against the model. |
| `-E` |  | Deploy even if BPA reports warnings. Only safe when `-V` has confirmed no BPA **errors** (warnings only). |
| `-R` |  | Report BPA results to stdout/console so they appear in the pipeline log. |
| `-M` |  | **Metadata only** — deploy structure, do not trigger data processing. Data processing is handled by the SQL Agent job (Section 5). |

### Org variable conventions

| Variable | Meaning | Notes |
|---|---|---|
| `$(tool_tabular_editor)` | Full path to `TabularEditor.exe` | Always `$(tool_tabular_editor_root)\TabularEditor.exe` |
| `$(tool_tabular_editor_scripts_path)` | Folder containing reusable TE2 C# scripts | |
| `$(artifact_dir)` | Release agent artifact root | |
| `$(sass_server)` | SSAS server name | **Intentional historical typo — do not "correct" to `ssas_server`.** Renaming breaks every pipeline. |
| `$(ssas_db)` | SQL instance qualifier on the SSAS server (e.g. `TABULAR01`) | |
| `$(ssas_catalog)` | Deployed SSAS database name | |

Connection string pattern (always this exact shape):

```
Provider=MSOLAP;Data Source=$(sass_server)\$(ssas_db);
```

### ADO Classic pipeline task configuration (Phase 3 — Deploy SSAS)

Two Command Line tasks, in this order:

**Task 1 — SSAS Schema Check**

```
Type:          Command Line
Display name:  SSAS Schema Check
Tool:          $(tool_tabular_editor)
Arguments:     "$(artifact_dir)\SSAS\Model.bim" -V -A -R
Fail on stderr: true
```

`-A` runs BPA against the offline `.bim` (no server contact). This task fails the release on BPA errors before any deploy attempt.

**Task 2 — SSAS Deploy**

```
Type:          Command Line
Display name:  SSAS Deploy
Tool:          $(tool_tabular_editor)
Arguments:     "$(artifact_dir)\SSAS\Model.bim" -S "$(tool_tabular_editor_scripts_path)\SetConnectionStringFromEnv.cs" -D "Provider=MSOLAP;Data Source=$(sass_server)\$(ssas_db);" "$(ssas_catalog)" -O -C -V -E -R -M
Fail on stderr: true
```

Both tasks must have **Fail on stderr = true** so BPA errors and TE2 exceptions fail the release.

## 3. Connection string replacement script

`SetConnectionStringFromEnv.cs` runs inside TE2 (`-S` flag) **before** the deploy step pushes the model to SSAS. It rewrites every `ProviderDataSource` connection string from an ADO release variable exposed to the agent as an environment variable.

```csharp
// SetConnectionStringFromEnv.cs — called by TabularEditor.exe -S flag during deploy.
// Rewrites all ProviderDataSource connection strings from ADO release variables.
var varName = "CTS_EAO_DWConnectionString"; // matches ADO release variable name pattern
var connString = Environment.GetEnvironmentVariable(varName);
if (string.IsNullOrEmpty(connString))
    throw new Exception($"Environment variable '{varName}' not set. Check ADO release variable configuration.");

foreach (var ds in Model.DataSources.OfType<ProviderDataSource>())
    ds.ConnectionString = connString;
```

### ADO release variable naming pattern

`{DataSourceName}ConnectionString` — e.g.

| Data source (in model) | ADO release variable |
|---|---|
| `CTS_EAO_DW` | `CTS_EAO_DWConnectionString` |
| `SNOW_DW` | `SNOW_DWConnectionString` |

Each environment (DEV, TEST, UAT, PROD, SUPPORT) holds its own value for the variable in its scoped variable group, so the **same** `.bim` artifact deploys cleanly to every environment.

For models with multiple data sources, extend the script to look up one variable per source, e.g. by iterating `Model.DataSources` and resolving `{ds.Name}ConnectionString`.

## 4. Processing modes (reference)

| Mode | TMSL `type` | When to use |
|---|---|---|
| Process Full | `"full"` | Complete reload of all data. Used in the release pipeline after deploy and for first-deploy-to-environment. |
| Process Default | `"automatic"` | Processes only what needs processing. Safe for ad-hoc re-runs after partial failures. |
| Process Recalc | `"calculate"` | Recalculates all calculated columns and relationships. No data refresh. |
| Process Add | `"add"` | Incremental partition add — appends new rows without reprocessing existing data. |
| Process Clear | `"clearValues"` | Clears all data; leaves model structure intact. Use before a Full to free memory on small servers. |

## 5. Processing in the pipeline (SQL Agent job pattern)

In this organisation, **SSAS processing is NOT triggered directly from the ADO pipeline**. Instead:

- **Phase 4** of the release pipeline calls `runDbaAgentJob.ps1`, which starts a **single SQL Agent job** on the DW server.
- The SQL Agent job has **one step** that:
  1. Runs the ELT process (calls the SSIS `Master_Orchestrator` package or executes the load stored procedures directly).
  2. Runs **SSAS Process Full** via XMLA/AMO once ELT completes successfully.

Why this pattern:

- Keeps ELT and SSAS processing **sequenced** in one place — no race conditions between pipeline tasks.
- All processing errors surface in one location (SQL Agent job history) so DBAs have a single pane of glass.
- Allows scheduled re-processing **independent** of the release pipeline — the same job can be scheduled nightly without re-running the pipeline.

### SQL Agent job step — SSAS processing (PowerShell / CmdExec)

The job step is configured as **Operating system (CmdExec)** type, invoking PowerShell with the script below (after ELT has succeeded in the same step's preceding logic):

```powershell
# Runs in SQL Agent job step (CmdExec type) after ELT completes.
# Loads Microsoft.AnalysisServices.Tabular and issues a Process Full via TMSL.
Import-Module SqlServer

$server   = "$(SSASServer)"   # set as SQL Agent job token, or hardcoded per env
$database = "$(SSASCatalog)"

$tmsl = @"
{
  "refresh": {
    "type": "full",
    "objects": [ { "database": "$database" } ]
  }
}
"@

$as = New-Object Microsoft.AnalysisServices.Tabular.Server
$as.Connect("Data Source=$server")
try {
    $result = $as.Execute($tmsl)
    if ($result.ContainsErrors) {
        throw "SSAS Process Full failed for database '$database' on '$server'."
    }
}
finally {
    $as.Disconnect()
}
```

### Alternative: AMO .NET (Invoke-ASCmd)

For environments where the `SqlServer` PowerShell module is preferred over raw AMO, use `Invoke-ASCmd`:

```powershell
Import-Module SqlServer

$server   = "$(SSASServer)"
$database = "$(SSASCatalog)"

$tmsl = @"
{
  "refresh": {
    "type": "full",
    "objects": [ { "database": "$database" } ]
  }
}
"@

$xml = Invoke-ASCmd -Server $server -Query $tmsl
if ($xml -match '<Exception' -or $xml -match '<Error') {
    throw "SSAS Process Full failed for '$database'. Response: $xml"
}
```

Both forms must throw on error so the SQL Agent job step fails, which in turn fails the ADO release Phase 4.

## 6. Processing order rules

These rules are critical — violating them causes relationship errors or stale data.

1. **Dimensions before facts.** Always process all dimension tables before any fact table. A fact processed before its dimension produces blank-row referential gaps.
2. **Calendar first.** `Calendar` (the date dimension) must be processed before any table with a date relationship — including before other dimensions that hold dates.
3. **Process Full on first deploy.** The first deployment to a new environment always uses Process Full — partitions don't exist yet, so Process Default is a no-op.
4. **Process Recalc after data changes that bypass partition processing.** If source data is patched but partition processing has already run, follow with Process Recalc so calculated columns and relationship caches refresh.
5. **A single Process Full at the database level** (as in Section 5) satisfies rules 1–4 automatically. Use per-table processing only for incremental loads.

## 7. Role deployment

- Roles **and** role membership are deployed by TE2's `-C` flag on the standard deploy command. There is no separate role-deploy step.
- Role membership (**AD group → role**) is defined in the TMDL/BIM. Changes in source control trigger re-deployment via the normal release pipeline.
- **Only AD groups** are used for role membership — never individual user accounts.

### Standard role pattern

| Role | Permission | Members |
|---|---|---|
| `{ProjectName} Consumers` | Read | AD group of business users |
| `{ProjectName} Authors` | Read + Process | AD group of model authors / analysts |

The Power BI Report Server (PBIRS) service account must be a member of the `Consumers` role (or a dedicated service role with Read) so published reports can query the model.

### Verify roles after deployment

Run against the SSAS XMLA endpoint in SSMS:

```sql
-- DMV: list roles and their model permission
SELECT [Name] AS RoleName, [ModelPermission]
FROM $SYSTEM.TMSCHEMA_ROLES;

-- DMV: list role membership (AD principals)
SELECT r.[Name] AS RoleName, m.[MemberName], m.[MemberID]
FROM $SYSTEM.TMSCHEMA_ROLES r
JOIN $SYSTEM.TMSCHEMA_ROLE_MEMBERSHIPS m ON r.[ID] = m.[RoleID];
```

## 8. Post-deployment validation queries

DMV queries to run as smoke tests after Phase 3 (deploy) and Phase 4 (processing). All run against the SSAS XMLA endpoint via SSMS or `Invoke-ASCmd`.

```sql
-- Tables deployed (excludes private/system tables)
SELECT [Name], [IsHidden], [Description]
FROM $SYSTEM.TMSCHEMA_TABLES
WHERE [IsPrivate] = FALSE;
```

```sql
-- Relationships active
SELECT [FromTableID], [ToTableID], [IsActive], [CrossFilteringBehavior]
FROM $SYSTEM.TMSCHEMA_RELATIONSHIPS;
```

```sql
-- Roles deployed
SELECT [Name], [ModelPermission]
FROM $SYSTEM.TMSCHEMA_ROLES;
```

```sql
-- Partitions processed (State = 1 = Ready). Returns rows ONLY if something is NOT ready.
SELECT t.[Name] AS TableName, p.[Name] AS PartitionName, p.[State]
FROM $SYSTEM.TMSCHEMA_PARTITIONS p
JOIN $SYSTEM.TMSCHEMA_TABLES t ON p.[TableID] = t.[ID]
WHERE p.[State] <> 1;
```

```sql
-- Measures deployed and visible
SELECT t.[Name] AS TableName, m.[Name] AS MeasureName, m.[IsHidden], m.[FormatString]
FROM $SYSTEM.TMSCHEMA_MEASURES m
JOIN $SYSTEM.TMSCHEMA_TABLES t ON m.[TableID] = t.[ID]
ORDER BY t.[Name], m.[Name];
```

A clean smoke test produces: tables list non-empty, relationships list non-empty, roles list contains both Consumers and Authors, partitions query returns **zero rows**.

## 9. Troubleshooting common deployment issues

| Symptom | Likely cause | Resolution |
|---|---|---|
| TE2 exits 1 during deploy with no error message | Wrong SSAS server/instance path in `-D` | Verify `$(sass_server)\$(ssas_db)` format; test by connecting from SSMS using the same string |
| `Catalog already exists` error | Model name conflict on existing database | Add `-O` flag to overwrite |
| Roles not deploying / consumers lose access after release | Missing `-C` flag on TE2 command | Add `-C` to the deploy arguments |
| Connection string not replaced; model points at DEV in PROD | Missing ADO release variable `{Name}ConnectionString` for that environment | Add the variable to the environment-scoped ADO variable group |
| BPA warnings fail the build but should be allowed | Missing `-E` flag | Add `-E` (only after confirming `-V` shows no BPA **errors**) |
| Processing fails immediately after deploy | ELT has not yet run; source tables empty or missing | Ensure Phase 4 runs **after** Phase 3, and that the SQL Agent job runs ELT before Process Full |
| Dimension process succeeds but fact fails on key violation | Calendar / parent dimension not yet processed | Verify Calendar and all referenced dimensions process before fact tables in the SQL Agent job (Section 6) |
| `The metadata for object ... is not valid` on deploy | Stale TMDL → `.bim` conversion in build artifact | Re-run the build pipeline; do not hand-edit the `.bim` |
| `Login failed for user 'NT Service\...'` during processing | SSAS service account lacks DB access to DW | Grant the SSAS service account `db_datareader` on the DW database |
| PBIRS reports return "no data" after successful deploy + process | PBIRS service account not in Consumers role | Add PBIRS service account's AD group to the Consumers role and redeploy |

## 10. Environments

Deployments target the following environments via environment-scoped variable groups in the ADO release definition:

`DEV` → `TEST` → `UAT` → `PROD` (with `SUPPORT` as a parallel non-production diagnostic environment).

Each environment supplies its own values for `$(sass_server)`, `$(ssas_db)`, `$(ssas_catalog)`, and every `{DataSourceName}ConnectionString` variable. The same `.bim` artifact flows through all environments unchanged.
