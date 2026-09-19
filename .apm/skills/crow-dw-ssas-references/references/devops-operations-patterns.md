<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# On-Premises Azure DevOps Server - Operations & Tooling Patterns

**Companion file to [devops-deployment-patterns.md](devops-deployment-patterns.md).** That file covers the Core Principles, Stack Overview, and per-component deployment steps (DACPAC, SSIS, SSAS Tabular, PBIRS). This file covers the supporting patterns: pipeline scripts, tooling setup, repository conventions, and operational procedures.

---

## 6. ELT Triggering from ADO Pipeline



SQL Agent is the production mechanism for triggering both SSIS ELT execution and SSAS processing

from the ADO pipeline. Use `runDbaAgentJob.ps1` from the shared library via `$(tool_runDbaAgentJob)`.



> **Shared script path on the agent**: `$(tool_scripts)\runDbaAgentJob.ps1`



### Script: `runDbaAgentJob.ps1` - Start SQL Agent Job and Wait



Starts a named SQL Agent job using dbatools and **waits for completion**, failing the pipeline

if the job fails.



```

Parameters:

  -sqlInstance    SQL Server instance hosting the Agent job (production pattern: "$(sass_server)\$(ssas_db)")

  -jobName        Name of the SQL Agent job to execute (production pattern: "$(agent_job_name)")

```



**What it does:**

1. Gets the job object from SQL Agent via `Get-DbaAgentJob`

2. Starts it with `Start-DbaAgentJob -Wait`

3. Checks `LastRunOutcome` and exits non-zero if the job did not succeed



**ADO Classic Pipeline task - Run ELT and Process SSAS:**

```

Task Type:      PowerShell

Display Name:   Run ELT and Process SSAS

Type:           File Path

File Path:      $(tool_runDbaAgentJob)

Arguments:      -sqlInstance "$(sass_server)\$(ssas_db)"

                -jobName "$(agent_job_name)"

```



> There is **one task** here, not separate ELT and SSAS-processing tasks.



### SQL Agent Job Conventions for SSIS / SSAS



- **One job per environment** named `{ENV}_{ProjectName}_Dataload` (for example `UAT_EAO_DW_Dataload`)

- The job runs the SSIS packages in sequence (staging -> dimensions -> facts) and then processes SSAS

- The SSIS orchestrator DTSX is triggered **inside the SQL Agent job**, not directly by the pipeline

- `runDbaAgentJob.ps1` is the pipeline wrapper that correctly fails the task if the SQL Agent job fails

- Job ownership should remain with the service account, not a personal login



---
## 7. PowerShell Script Standards for ADO Pipelines

All pipeline scripts must follow these conventions:

```powershell
# Template for any pipeline PowerShell script
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $RequiredParam,
    [string] $OptionalParam = 'DefaultValue'
)

# Always set this — pipeline needs non-zero exit on error
$ErrorActionPreference = 'Stop'

try {
    # ---- main logic here ----
    Write-Host "Step complete."
    exit 0
}
catch {
    Write-Error "Script failed: $_"
    exit 1   # ADO pipeline reads exit code; non-zero = fail
}
```

**Rules:**
- `[CmdletBinding()]` + `param()` block — all values come from parameters, never from the environment directly
- `$ErrorActionPreference = 'Stop'` — ensures any cmdlet error bubbles up
- `try/catch` wrapping main logic — always `exit 1` on failure
- `Write-Host` for progress (captured in ADO pipeline log)
- `Write-Error` before `exit 1` — shows red error in pipeline log
- **No `Write-Host` of secrets** — pass secrets as pipeline variables marked as `secret`

---

## 8. Repository Structure for Automated DW Projects



```

YourDWProject/

|-- design/                            # Requirements and design artifacts — agent-maintained, committed to git
|   |-- spec.md                        # Living design specification (update in-place, never regenerate)
|   |-- decisions.md                   # Decisions register: business definitions, ADRs, deferred scope
|   |-- bus-matrix.md                  # Signed-off enterprise bus matrix (update when model changes)
|   |-- entity-map.md                  # Source entity map from Mode P discovery (update on re-run)
|   `-- glossary.md                    # Canonical project terminology (built incrementally; only created when first term is agreed)

|-- DW/                                # SSDT solution and database project

|   |-- {ProjectName}.sln

|   |-- {ProjectName}.sqlproj

|   |-- Dimension/                     # One .sql file per table/view/SP — e.g. Calendar.sql, LoadCustomer.sql

|   |-- Fact/

|   |-- Staging/

|   |-- Internal/

|   |-- SSAS/                          # SSAS schema views: one .sql file per view

|   `-- Scripts/

|       `-- Post-Deployment/

|-- SSIS/

|   `-- {ProjectName}_SSIS/            # SSIS solution folder built by devenv.com

|       |-- {ProjectName}_SSIS.sln

|       |-- *.dtproj

|       |-- *.dtsx

|       `-- ssis_catalog_configuration.json

|-- SSAS/

|   `-- {ModelName}/                   # TMDL folder (Tabular Editor "Save as folder")

|       |-- database.tmdl

|       |-- model.tmdl

|       |-- tables/

|       |-- relationships/

|       `-- roles/

`-- Reports/

    `-- *.pbix

```

> **Classic pipeline definitions are stored in the ADO Server UI, not in this repo.**

> Shared deployment scripts run from the agent path `$(tool_scripts)\` and should be

> referenced through the shared `Tools` variable group wherever a `$(tool_*)` variable is available.



---
## 9. Checklist - Is This Deployable via Pipeline?



Use this when generating or reviewing any solution component:



| Item | Required Behavior | Y |

|---|---|---|

| No hardcoded server names | All server references via parameters/variables | |

| No hardcoded credentials | Secrets come from ADO variable group (marked secret) | |

| Idempotent scripts | Re-running = update, not duplicate or error | |

| Exit codes set | `exit 0` / `exit 1` for ADO task success/failure detection | |

| SSIS packages committed | `.dtsx` files committed to git; deployed from the built `.ispac` artifact | |

| SSIS deployed via marketplace task | Use the SSIS Deploy task, then Replace Tokens, then Configure SSIS Catalog | |

| SSAS deployed via TE CLI | Deploy `Model.bim` artifact built from TMDL in the build pipeline | |

| SSAS connection parameterized | `SetConnectionStringFromEnv.cs` reads environment-specific ADO variables | |

| PBIX connection updated | `PBIRS-deployPbixReports.ps1` updates SSAS connection per environment | |

| DACPAC safe defaults | Publish with the real `sqlpackage.exe` task and integrated security connection string | |

| Extended properties in SSDT | Post-deploy scripts, not ad-hoc SSMS execution | |

| Single SQL Agent job orchestrates runtime | `{ENV}_{Project}_Dataload` triggers both SSIS ELT **and** SSAS processing in sequence | |

| Pipeline stages ordered | DB schema -> SSIS deploy -> SSAS deploy -> ELT+SSAS process -> PBIX reports | |

| Shared scripts used | Reference agent scripts from `$(tool_scripts)\` via `$(tool_*)` variables where available | |

| dbatools installed on agent | Required by: `runsqlfile`, `runDbaAgentJob`, `backupdatabase`, `createSqlLogin` | |

| ReportingServicesTools installed | Required by: `PBIRS-deployPbixReports`, `PBIRS-deployPaginatedReports` | |



---
## 10. Shared PowerShell Script Library



Agent path:  `$(tool_scripts)\`

Dev source:  `$(tool_scripts)\`

ADO reference: via variable group **Tools** -> `$(tool_*)` variables



Classic pipelines should call the shared agent copies, not repo-local duplicates.



### DW Deployment Scripts



| Script | Purpose | Referenced as |

|---|---|---|

| `runsqlfile.ps1` | Run a `.sql` file against a target database | `$(tool_run_sql_file)` |

| `runDbaAgentJob.ps1` | Start a SQL Agent job and wait for completion | `$(tool_runDbaAgentJob)` |

| `createSqlLogin.ps1` | Create/repair the `dw` SQL login used by the environment | `$(tool_create_sql_login)` |

| `backupdatabase.ps1` | Backup a database before refresh/deployment workflows | `$(tool_db_backup)` |

| `copyAndRefresh.ps1` | Copy and restore a database backup into another environment | `$(tool_copyAndRestore)` |

| `archivedirectory.ps1` | Archive directories on the agent or shared storage | `$(tool_archive_directory)` |



### PBIRS Deployment Scripts



| Script | Purpose | Referenced as |

|---|---|---|

| `PBIRS-deployPbixReports.ps1` | Deploy `.pbix` files and update SSAS live-connection settings | `$(tool_PBIRS-deployPbixReports)` |

| `PBIRS-deployPaginatedReports.ps1` | Deploy `.rdl`/`.rsd`/`.rds` content to PBIRS | shared agent path / optional variable |

| `PBIRS-updateConnection.ps1` | Update report connection settings without re-uploading the file | shared agent path / optional variable |



### Module Installation (Run on Build/Release Agent)



```powershell

# Run once on the build/release agent as Administrator

Install-Module dbatools               -Scope AllUsers -Force

Install-Module ReportingServicesTools -Scope AllUsers -Force

```



### Common ADO Classic Pipeline Task Pattern



There are **two** common task patterns in the production pipelines:



**1. PowerShell task (`e213ff0f`)**



```

Task Type:      PowerShell

Type:           File Path

File Path:      $(tool_run_sql_file)

Arguments:      -sqlinstance "$(db_server)\$(db)"

                -dbname "$(db_catalog)"

                -file "$(artifact_dir)\DW\SQL\loadStaging.sql"

```



**2. Command Line task (`d9bafed4`)**



```

Task Type:      Command Line

Filename:       $(sql_package_2019)

Arguments:      /action:Publish /sourceFile:"$(artifact_dir)\DW\Release\{ProjectName}.dacpac" /targetconnectionstring:"Data Source=$(db_server)\$(db);Initial Catalog=$(dw_db_catalog);Integrated Security=True;Connection Timeout=150;Persist Security Info=False;"

```



> **Secret variables** use the same `$(VariableName)` syntax. ADO masks their values in logs.



---



## 11. TabularEditor Tools Package



The TabularEditor toolset is managed outside individual DW repos and deployed onto the agent.



- **Agent path**: `$(tool_tabular_editor_root)\`

- **Dev source**: `$(tool_tabular_editor_root)\`



**Package structure**



```

TabularEditor/

|-- Portable/

|   `-- TabularEditor.exe

|-- Rules/

|   `-- BPARules.json

`-- Scripts/

    |-- SetConnectionStringFromEnv.cs

    |-- SetADConnectionStringFromEnv.cs

    `-- ClearConnectionString.cs

```



**What each component is used for**



| Component | Purpose | Used in |

|---|---|---|

| `Portable\TabularEditor.exe` | Portable executable used by ADO Command Line tasks | Build steps 8-10 and Release Phase 3 |

| `Rules\BPARules.json` | Standard Best Practices Analyzer rules loaded by the `-A` flag | Build step 8 |

| `Scripts\ClearConnectionString.cs` | Clears connection strings before validation deployment | Build step 9 |

| `Scripts\SetConnectionStringFromEnv.cs` | Applies `{DataSourceName}ConnectionString` env vars before schema check/deploy | Release Phase 3 |

| `Scripts\SetADConnectionStringFromEnv.cs` | Alternative script for AD impersonation scenarios | Available but not used in current pipelines |



`BPARules.json` is managed as part of the shared TabularEditor package so every project uses the

same analyzer rules when the build pipeline runs the Best Practices Analyzer.

---

## ALM Toolkit Workflow

### Purpose
ALM Toolkit (free, https://alm-toolkit.com) is used for schema-only SSAS Tabular model comparisons and deployments. Unlike Tabular Editor deploy (which always does a full metadata replace), ALM Toolkit identifies delta changes and can deploy only what changed — reducing processing requirements and deployment risk.

### When to use ALM Toolkit vs Tabular Editor deploy
| Scenario | Tool |
|---|---|
| Initial model deployment (new model) | Tabular Editor 2 CLI (`-D` flag) |
| Full metadata replace (overwrite everything) | Tabular Editor 2 CLI (`-D` flag) |
| Schema-only delta deployment (add/modify measures, columns) | ALM Toolkit |
| Promoting a model from DEV → TEST with structural changes | ALM Toolkit |
| Checking what changed between two model versions | ALM Toolkit (compare only) |
| Partition management | SSMS or SQL Agent job (separate from model deploy) |

### ALM Toolkit comparison modes
1. **File vs Server**: compare a `.bim` file (artifact) to a live SSAS instance — used in release pipelines
2. **Server vs Server**: compare DEV SSAS to TEST SSAS directly — used for drift detection
3. **File vs File**: compare two `.bim` artifacts — used for code review / diff

### Release pipeline integration (ADO Classic)
ALM Toolkit does not have a native ADO task. The approved pattern uses PowerShell:

```powershell
# ALM Toolkit comparison and deployment via PowerShell
# Requires ALM Toolkit installed on the build agent at $(tool_alm_toolkit_root)\

$almExe    = "$(tool_alm_toolkit_root)\ALMToolkit.exe"
$sourceBim = "$(artifact_dir)\$(ssas_db).bim"
$targetAS  = "$(sass_server)"   # Note: sass_server is intentional historical variable name
$targetDB  = "$(ssas_db)"

# Generate comparison script (no deployment yet)
& $almExe -s $sourceBim -t "Provider=MSOLAP;Data Source=$targetAS;Initial Catalog=$targetDB" `
          -script "$(artifact_dir)\delta.xmla" -o

# Review $(artifact_dir)\delta.xmla in pipeline log (optional)

# Apply the delta
Invoke-ASCmd -Server $targetAS -Database $targetDB `
             -InputFile "$(artifact_dir)\delta.xmla"
```

Note: `$(sass_server)` is the intentional historical variable name — do not correct to `ssas_server`.

### Drift detection (Server vs Server)
Run this check as part of the DEV → TEST promotion gate to detect configuration drift:

```powershell
# Compare DEV to TEST and fail pipeline if structural differences exist
$almExe = "$(tool_alm_toolkit_root)\ALMToolkit.exe"

& $almExe -s "Provider=MSOLAP;Data Source=$(sass_server_dev);Initial Catalog=$(ssas_db)" `
          -t "Provider=MSOLAP;Data Source=$(sass_server_test);Initial Catalog=$(ssas_db)" `
          -script "$(artifact_dir)\drift.xmla" -o

if ((Get-Content "$(artifact_dir)\drift.xmla") -match "alter|create|delete") {
    Write-Host "##vso[task.logissue type=warning]Structural drift detected between DEV and TEST"
}
```

### Options to preserve during deployment
When deploying with ALM Toolkit, always preserve:
- **Partitions** — never overwrite; partition management is handled separately
- **Role memberships** — AD group assignments are environment-specific; overwriting deletes them
- **Data sources** — connection strings are environment-specific

In ALM Toolkit GUI: Options → Deployment → check "Retain Partitions", "Retain Role Members", "Retain Data Sources".
In scripted mode: add `-RetainPartitions -RetainRoleMembers -RetainDataSources` flags (verify flag names match installed ALM Toolkit version).

### Review checklist (Mode G — Deployment Review)
| Check | Severity if failed |
|---|---|
| ALM Toolkit used for delta deployments (not always full replace) | 🟡 MEDIUM |
| Partitions preserved during ALM Toolkit deployment | 🔴 CRITICAL |
| Role memberships preserved during ALM Toolkit deployment | 🔴 CRITICAL |
| Data sources preserved (not overwritten with DEV connection strings) | 🔴 CRITICAL |
| Drift detection run before TEST/UAT promotion | 🟡 MEDIUM |

---

## 12. Incident Response - Roll-Forward Philosophy

### Philosophy

This organisation uses a **roll-forward** approach to production incidents. When a defect is
discovered in PROD, the response is to fix it, test it, and deploy the fix - not to revert to
a previous deployment. Reverting is a last resort reserved for catastrophic failures where a
forward fix cannot be produced quickly.

**Why roll-forward works here:**
- All code is in Git - every deployed state is reproducible from source
- The multi-environment promotion chain (DEV ? TEST ? UAT ? PROD) catches defects before PROD
- SUPPORT mirrors PROD - a safe diagnostic environment exists without touching live data
- All deployment steps are automated and idempotent - redeploying any commit is a pipeline run

### Branch Model

```
main        - always reflects what is currently deployed to PROD
dev         - long-running integration branch; all development and hotfixes land here first

feature/*   - short-lived branches off dev, merged to dev when ready
hotfix/*    - short-lived branches off dev for urgent fixes (optional; can also commit directly to dev)
```

**`main` is never directly committed to.** It is only updated by merging `dev` after a successful
PROD deployment, to keep it in sync with what is live.

### Normal Promotion Flow

```
dev  --? DEV pipeline  --? TEST pipeline  --? UAT pipeline  --? PROD pipeline
                                                                        -
                                                                        ?
                                                               merge dev ? main
                                                          (main now mirrors PROD)
```

Each environment runs the same pipeline definition with environment-specific variable groups.
Promotion to the next environment is a manual approval gate in ADO.

### Hotfix Flow

When a defect is found in PROD:

1. **Fix is committed to `dev`** - the same integration branch used for all development
2. **Pipeline is run from `dev`** - promotes through DEV ? TEST ? UAT ? PROD as normal
   - UAT gate can be fast-tracked if the fix is low-risk and urgency is high
   - SUPPORT environment can be used to verify the fix against a PROD-mirror before UAT if needed
3. **After successful PROD deployment** - merge `dev` ? `main` to keep `main` in sync

```
dev (with fix)  --? DEV  --? TEST  --? UAT (fast-track ok)  --? PROD
                                                                     -
                                                                     ?
                                                            merge dev ? main
```

### SUPPORT Environment

SUPPORT is a diagnostic mirror of PROD. It is refreshed from the same source as PROD on the
same schedule. Use it to:
- Reproduce a PROD incident without risk to live data or users
- Investigate data quality issues against PROD-equivalent data
- Optionally verify a hotfix before promoting to UAT (no restriction, but not the standard path)

SUPPORT is **never** the target of a feature deployment - only the nightly refresh pipeline runs
against it.

### Emergency Rollback (Last Resort)

Rollback is not the default response, but it is available. Because all artefacts are built from
Git-tracked source, "rollback" means re-running the pipeline against the last known-good commit.

**To redeploy a previous version:**
1. Identify the last good commit SHA or release tag in ADO
2. Trigger the pipeline manually, pointing it at that commit
3. The pipeline is idempotent - redeploying a previous state is safe

**Per-component notes:**

| Component | "Rollback" mechanism | Notes |
|---|---|---|
| **SQL DW (DACPAC)** | Re-deploy previous `.dacpac` built from last good commit | DACPAC is forward-only by default - no down scripts. SqlPackage will apply the diff between current schema and previous schema. Destructive changes (dropped columns) require explicit `--p:BlockOnPossibleDataLoss=false`. |
| **SSAS Tabular model** | Re-deploy previous TMDL JSON via TE2 CLI against PROD AS instance | Git-tracked TMDL files are the source of truth - no `.abf` backup required. TE2 deploy overwrites the model. |
| **SSIS packages** | Re-deploy previous `.ispac` via ISDeploymentWizard | SSIS catalog stores the active version - re-deployment replaces it. |
| **PBIRS reports** | Re-deploy previous `.pbix` via PBIRS REST API | The REST API upload overwrites the report. Previous versions are not retained by PBIRS natively - Git is the version store. |

> **Note on DACPAC data-loss risk:** If the bad PROD deployment included a destructive schema change
> (e.g., a column drop that removed data), a DACPAC rollback cannot recover that data. In this case,
> roll-forward with a schema fix is the only viable path. This scenario is mitigated by the
> UAT testing gate - destructive changes should never reach PROD untested.
