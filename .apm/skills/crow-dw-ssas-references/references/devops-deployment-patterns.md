<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# On-Premises Azure DevOps Server — Deployment Automation Patterns

**Scope**: This reference covers all deployment and automation patterns for a traditional on-premises
Data Warehouse stack orchestrated from **Azure DevOps Server (on-premises)**. Every artifact —
database changes, SSIS packages, SSAS Tabular models, and PBIX reports — must be deployable via a
pipeline step with no manual GUI interaction.

---

## Core Principles

1. **Script-first**: Every deployment must be executable as a PowerShell or command-line step.
2. **Parameter-driven**: No hardcoded server names, database names, paths, or credentials anywhere. All values come from pipeline variables or SSISDB environments.
3. **Idempotent**: Scripts must be safe to re-run (deploy again = update, not duplicate).
4. **Exit-code aware**: All PowerShell scripts must return `exit 0` (success) or `exit 1` (failure) so ADO pipeline tasks correctly detect failures.
5. **Ordered deployment**: DB schema → ELT packages → SSAS model → PBIX reports. Later stages depend on earlier ones succeeding.
6. **Environment-segregated**: Dev / Test / Prod differences live in ADO variable groups and SSISDB environments, not in code.

---

## Stack Overview

```
On-Premises Azure DevOps Server
    │
    ├── Self-hosted Build/Release Agent (Windows Server)
    │       ├── Visual Studio Build Tools (MSBuild, SqlPackage.exe)
    │       ├── SQL Server Integration Services (ISDeploymentWizard.exe)
    │       ├── Tabular Editor 2 CLI (TabularEditor.exe — free, open-source)
    │       ├── Analysis Services PowerShell module (SqlServer)
    │       └── PowerShell 5.1+ / PowerShell Core
    │
    ├── Classic Pipeline Stages (run in sequence)
    │       1. Build          — compile DACPAC, .ispac, validate model files
    │       2. Deploy DB      — SqlPackage.exe publishes DACPAC to SQL Server
    │       3. Deploy SSIS    — .ispac deployed to SSISDB; environments configured
    │       4. Run ELT        — SQL Agent job executed (or direct SSIS invocation)
    │       5. Deploy SSAS    — Tabular model deployed via Tabular Editor CLI
    │       6. Process SSAS   — Full/incremental process via XMLA or PowerShell
    │       7. Deploy PBIX    — PBIX files uploaded via PBIRS REST API
    │
    └── ADO Variable Groups (Library)
            DW-Dev, DW-Test, DW-UAT, DW-Prod
            (SQL server, SSAS server, PBIRS URL, credentials)
            Linked to each Release pipeline stage
```

---

## 1. ADO Classic Pipeline Structure (Primary)



Azure DevOps Server uses **Classic Pipelines** - the visual task editor - as the primary

deployment mechanism. Classic pipelines are configured through the ADO Server UI, not stored

as YAML files in the repository.



> **YAML pipelines are optional.** The production source of truth for these DW deployments is the

> Classic build pipeline plus the Classic release pipeline stages described below.



### Classic Release Pipeline Layout



Configure a **Release Pipeline** in ADO Server with one stage per environment. Each stage uses the

same five phases; only the linked variable values change.



```

Release Pipeline: DW_Deploy

|

+-- Stage: Deploy to DEV / TEST / UAT / PROD / SUPPORT
|   (SUPPORT mirrors PROD configuration — used for production-support investigations
|    without touching PROD; shares PROD variable values with a separate agent pool slot)
|   +-- Phase 1: Deploy DW DB
|   |   1. PowerShell: $(tool_create_sql_login)

|   |   2. Command Line: $(sql_package_2019) publishes DW\Release\{ProjectName}.dacpac to $(dw_db_catalog)

|   |   3. PowerShell: $(tool_run_sql_file) runs loadStaging.sql against source DB $(db_catalog)

|   |

|   +-- Phase 2: Deploy SSIS

|   |   1. SSIS Deploy marketplace task (.ispac -> SSISDB)

|   |   2. Replace Tokens on ssis_catalog_configuration.json

|   |   3. Configure SSIS Catalog from the tokenized JSON file

|   |

|   +-- Phase 3: Deploy SSAS Tabular

|   |   1. Command Line: TabularEditor schema check on $(artifact_dir)\SSAS\Model.bim

|   |   2. Command Line: TabularEditor deploy to $(sass_server)\$(ssas_db) / $(ssas_catalog)

|   |

|   +-- Phase 4: Run ELT and Process SSAS

|   |   1. PowerShell: $(tool_runDbaAgentJob) runs the single SQL Agent job $(agent_job_name)

|   |

|   `-- Phase 5: Deploy Reports

|       1. PowerShell: $(tool_PBIRS-deployPbixReports)

|

`-- Each stage links:

    - shared variable group: Tools

    - environment-specific variables: db, db_server, db_catalog, dw_db_catalog, sass_server,

      ssas_db, ssas_catalog, agent_job_name, reportPortalUri, rsFolderPath, reportsToUpdate,

      and the required {DataSourceName}ConnectionString release variable(s)

```



### Classic Build Pipeline Layout



Configure a **Build Pipeline** in ADO Server to produce the `drop` artifact in this order:



```

Build Pipeline: DW_Build

|

`-- Agent Job: Build Artifacts

    1. NuGet restore

    2. DW Build (Visual Studio Build) - builds DW\{ProjectName}.sln

    3. Copy dacpac - **\**.dacpac -> $(Build.ArtifactStagingDirectory)\DW

    4. Copy sql files - **\**.sql -> $(Build.ArtifactStagingDirectory)\DW\SQL (Flatten = true)

    5. SSIS Build (Command Line / devenv.com) - {ProjectName}_SSIS.sln /Build Development

    6. SSIS Copy ISPAC - **\**.ispac -> $(Build.ArtifactStagingDirectory)\SSIS (Flatten = true)

    7. SSIS Copy catalog config - **\**.json -> $(Build.ArtifactStagingDirectory)\SSIS (Flatten = true)

    8. TabularEditor - Best Practices Analyzer

    9. TabularEditor - Validation Deployment

   10. TabularEditor - Build (TMDL folder -> Model.bim)

   11. Copy PBIX files - **\**.pbix -> $(Build.ArtifactStagingDirectory)\Reports (Flatten = true)

   12. Publish Artifact - drop

   13. Clean Agent Directories

```



### Adding a PowerShell Task in Classic Pipeline



Production pipelines use **two task types** in Classic release/build definitions:



**1. PowerShell task (`e213ff0f`)** - used for shared scripts in `$(tool_scripts)\`



```

Task Type:      PowerShell

Display Name:   Run loadStaging.sql on source DB

Type:           File Path

File Path:      $(tool_run_sql_file)

Arguments:      -sqlinstance "$(db_server)\$(db)"

                -dbname "$(db_catalog)"

                -file "$(artifact_dir)\DW\SQL\loadStaging.sql"

```



**2. Command Line task (`d9bafed4`)** - used for direct executables such as `sqlpackage.exe`

and `TabularEditor.exe`



```

Task Type:      Command Line

Display Name:   Deploy SSAS Tabular

Filename:       $(tool_tabular_editor)

Arguments:      "$(artifact_dir)\SSAS\Model.bim" -S "$(tool_tabular_editor_scripts_path)\SetConnectionStringFromEnv.cs" -D "Provider=MSOLAP;Data Source=$(sass_server)\$(ssas_db);" "$(ssas_catalog)" -O -C -V -E -R -M

Working Folder: $(System.DefaultWorkingDirectory)

```



> **All variable references** use `$(VariableName)` syntax in Classic pipelines.

> Link the shared **Tools** variable group plus the environment-specific variables to each stage.



### Variable Group Setup



Production pipelines use **two variable sources** per stage.



**Shared variable group: `Tools`**



| Variable | Value |

|---|---|

| `tool_tabular_editor` | `$(tool_tabular_editor_root)\TabularEditor.exe` |

| `tool_tabular_editor_scripts_path` | `$(tool_tabular_editor_root)\Scripts` |

| `tool_run_sql_file` | `$(tool_scripts)\runsqlfile.ps1` |

| `tool_runDbaAgentJob` | `$(tool_scripts)\runDbaAgentJob.ps1` |

| `tool_create_sql_login` | `$(tool_scripts)\createSqlLogin.ps1` |

| `tool_PBIRS-deployPbixReports` | `$(tool_scripts)\PBIRS-deployPbixReports.ps1` |

| `tool_archive_directory` | `$(tool_scripts)\archivedirectory.ps1` |

| `tool_db_backup` | `$(tool_scripts)\backupdatabase.ps1` |

| `tool_copyAndRestore` | `$(tool_scripts)\copyAndRefresh.ps1` |

| `artifact_dir` | `$(System.DefaultWorkingDirectory)\$(Build.DefinitionName)\drop` |

| `sql_package_2019` | `$(tool_sqlpackage)` |



**Environment-specific variables / stage overrides**



| Variable | Purpose |

|---|---|

| `db` | SQL Server instance name |

| `db_server` | SQL Server host name |

| `db_catalog` | source OLTP/source-system database used by `loadStaging.sql` |

| `dw_db_catalog` | DW target database for the DACPAC publish |

| `sass_server` | SSAS host name used by the release pipeline (intentional variable name) |

| `ssas_db` | SQL instance name on the SSAS server |

| `ssas_catalog` | deployed SSAS catalog/database name |

| `agent_job_name` | single SQL Agent job that runs ELT and SSAS processing |

| `reportPortalUri` | PBIRS portal URL |

| `rsFolderPath` | PBIRS destination folder |

| `reportsToUpdate` | optional comma-separated PBIX names; blank = deploy all |

| `{DataSourceName}ConnectionString` | release variable consumed by TabularEditor C# scripts (for example `CTS_EAO_DWConnectionString`) |



Mark credentials as **secret variables**. Link both the shared `Tools` group and the environment-specific

variables under **Stage -> Variables**.



### Self-Hosted Agent Requirements



The build/release agent must have these tools and modules installed:



| Tool / Module | Install / Path | Used by |

|---|---|---|

| `sqlpackage.exe` | `$(sql_package_2019)` | DACPAC publish (Release Phase 1) |

| `TabularEditor.exe` | `$(tool_tabular_editor)` in `$(tool_tabular_editor_root)\` | BPA, validation deploy, `.bim` build, SSAS deploy |

| Visual Studio `devenv.com` | `$(devenv_path)` | SSIS Build step |

| SSIS Deploy marketplace extension | Installed in ADO Server | SSIS `.ispac` deployment |

| SSIS Catalog Configuration marketplace extension | Installed in ADO Server | SSIS catalog environment configuration |

| Replace Tokens extension | Installed in ADO Server | token replacement in `ssis_catalog_configuration.json` |

| PowerShell module: **dbatools** | `Install-Module dbatools` | `runsqlfile.ps1`, `runDbaAgentJob.ps1`, `backupdatabase.ps1`, `createSqlLogin.ps1`, `copyAndRefresh.ps1` |

| PowerShell module: **ReportingServicesTools** | `Install-Module ReportingServicesTools` | `PBIRS-deployPbixReports.ps1`, `PBIRS-deployPaginatedReports.ps1` |

| PowerShell 5.1+ | Included with Windows Server | shared script execution |

| 7-Zip (`7z.exe`) | [7-zip.org](https://www.7-zip.org/) | `archivedirectory.ps1` |



> **Shared script library on the agent**: `$(tool_scripts)\`

> The shared **Tools** variable group exposes these paths as `$(tool_*)` variables. Do not hardcode

> agent paths in task configurations.



---



### Optional: YAML Pipeline Equivalent

> **On-Premises only:** This organisation uses **Azure DevOps Server** (on-premises), not Azure DevOps Services (cloud). YAML pipelines are supported in Azure DevOps Server 2019+, but all existing pipelines use the Classic pipeline UI.
>
> If a YAML equivalent is created, it must mirror the same task order, task types, and `$(tool_*)` variable references shown in the Classic pipeline above. YAML cloud-only features (e.g., environments with approval gates from Azure DevOps Services, service connections to Azure, Microsoft-hosted agents) are **❌ not available** in this environment.



---
## 2. SSDT / DACPAC Deployment



### Production Phase 1 Pattern (replaces `scripts/Deploy-DACPAC.ps1`)



Production releases do **not** use a repo-local wrapper such as `Deploy-DACPAC.ps1`. The real

Classic release pattern is a three-step **Deploy DW DB** phase:



**Step 1 - PowerShell task (`e213ff0f`)**: `createSqlLogin.ps1`



```

Task Type:      PowerShell

Display Name:   Create DW SQL Login

Type:           File Path

File Path:      $(tool_create_sql_login)

Arguments:      -sqlInstance "$(db_server)\$(db)" -sqlLogin "dw" -sqlPass "dw"

```



> The `dw` SQL login and password are intentional for these environments.



**Step 2 - Command Line task (`d9bafed4`)**: publish the DACPAC with `sqlpackage.exe`



```

Task Type:      Command Line

Display Name:   Deploy DACPAC

Filename:       $(sql_package_2019)

Arguments:      /action:Publish /sourceFile:"$(artifact_dir)\DW\Release\{ProjectName}.dacpac" /targetconnectionstring:"Data Source=$(db_server)\$(db);Initial Catalog=$(dw_db_catalog);Integrated Security=True;Connection Timeout=150;Persist Security Info=False;"

```



> This uses **Windows Integrated Security** for the publish connection string, not the `dw` SQL login.



**Step 3 - PowerShell task (`e213ff0f`)**: run `loadStaging.sql` on the source database



```

Task Type:      PowerShell

Display Name:   Deploy loadStaging.sql

Type:           File Path

File Path:      $(tool_run_sql_file)

Arguments:      -sqlinstance "$(db_server)\$(db)" -dbname "$(db_catalog)" -file "$(artifact_dir)\DW\SQL\loadStaging.sql"

```



> `loadStaging.sql` is executed against the **source database** `$(db_catalog)`, not the DW database.

> This deploys the stored procedures that SSIS uses for incremental extraction.



### SSDT Project Conventions for Automation



- **Publish profiles** (`*.publish.xml`) per environment in `DW\PublishProfiles\`:

  - `Dev.publish.xml`, `Test.publish.xml`, `Prod.publish.xml`

  - Each profile contains only server/db overrides - no secrets

- **Extended property scripts** in `Scripts\Post-Deployment\ExtendedProperties\` - use upsert pattern

- **Pre/post-deploy scripts** must be idempotent (`IF NOT EXISTS ... / IF EXISTS ...`)

- **SQLCMD variables** for environment-specific values referenced in scripts



---
## 3. SSIS Package Deployment



### Production Phase 2 Pattern (replaces `scripts/Deploy-SsisProject.ps1`)



Production releases use three Classic tasks for **Deploy SSIS**:



**Task 1 - SSIS Deploy marketplace task (`06d2a35b-20bd-4f63-b331-b89eb168517b`)**



```

sourcePath:         $(System.DefaultWorkingDirectory)/{ArtifactAlias}/drop/SSIS/{ProjectName}_SSIS.ispac

destinationType:    ssisdb

destinationServer:  $(db_server)\$(db)

destinationPath:    /SSISDB/{ProjectName}-Dataload

authType:           win

whetherOverwrite:   yes

whetherContinue:    no

```



**Task 2 - Replace Tokens marketplace task (`a8515ec8`)**



```

rootDirectory:  $(artifact_dir)/SSIS

targetFiles:    ssis_catalog_configuration.json

tokenPattern:   doublebraces   (#{...}#)

```



**Task 3 - Configure SSIS Catalog marketplace task (`ff0067f5`)**



```

configSource:     filePath

configPath:       $(artifact_dir)/SSIS/ssis_catalog_configuration.json

targetServer:     $(db_server)\$(db)

authType:         win

rollBackOnError:  true

```



### `ssis_catalog_configuration.json`



- The file is stored with the SSIS solution in source control: `SSIS\{ProjectName}_SSIS\ssis_catalog_configuration.json`

- It contains token placeholders in the form `#{VariableName}#`

- The **Replace Tokens** task injects pipeline variable values into the JSON during release

- The **Configure SSIS Catalog** task then reads that JSON and creates/updates SSISDB environment values

- Standard variables configured this way are:

  - `ssis_param_LoadType` = `I` (incremental)

  - `ssis_param_SourceDB`

  - `ssis_param_SourceServer`

  - `ssis_param_TargetDB`

  - `ssis_param_TargetServer`



### SSISDB Environment Variables



In production, SSIS catalog variables are managed from `ssis_catalog_configuration.json` plus the

release variables above - not from an ad-hoc PowerShell deployment wrapper.



### SSIS Project Conventions for Automation



- **Project deployment model only** - never package deployment

- **All connection strings via project parameters** mapped to SSISDB environment variables

- **No hardcoded paths or server names** inside any SSIS package

- **The orchestrator package is triggered indirectly** by the Phase 4 SQL Agent job, not by a separate

  pipeline SQL snippet. The job runs the SSIS packages in sequence and then processes SSAS.



---
## 4. SSAS Tabular Model Deployment



### Environment Naming Convention



The source-controlled model folder name and the deployed SSAS catalog name are related but not

identical:



| Artifact | Example |

|---|---|

| TMDL folder / model source | `EAO_Tabular`, `ESB_Tabular` |

| Release target catalog (`$(ssas_catalog)`) | `EAO_UAT`, `ESB_UAT` |

| SSAS server / instance | `$(sass_server)\$(ssas_db)` |



Developers can still deploy locally for development, but release stages deploy the validated build

artifact to the environment-specific `$(ssas_catalog)`.



### Source Control: Always Use TMDL Folder



- The **TMDL folder** is the source of truth in git

- Tabular Editor workflow: **Open from folder** -> edit -> **Save as folder** -> commit

- TMDL gives granular git diffs: one `.tmdl` file per table/role/relationship



### Build vs. Release: TMDL -> `.bim` Workflow



- The **TMDL folder** is the source-control format used in `SSAS\{ModelName}\`

- **Build step 10** runs `TabularEditor.exe -B` to convert that TMDL folder into `$(Build.ArtifactStagingDirectory)\SSAS\Model.bim`

- The build also performs a **validation deployment** first, using `ClearConnectionString.cs`, to prove the model compiles and can deploy

- The **release pipeline deploys `Model.bim`**, not the TMDL folder

- This guarantees the exact artifact validated during build is the artifact promoted through release



### Option A: Tabular Editor CLI (Recommended)



Production releases use **two Command Line tasks** in Phase 3.



**Step 1 - TabularEditor Schema Check (`d9bafed4`)**



```

Task Type:      Command Line

Display Name:   TabularEditor Schema Check

Filename:       $(tool_tabular_editor)

Arguments:      "$(artifact_dir)\SSAS\Model.bim" -S "$(tool_tabular_editor_scripts_path)\SetConnectionStringFromEnv.cs" -SC -V

```



**Step 2 - TabularEditor Deploy (`d9bafed4`)**



```

Task Type:      Command Line

Display Name:   Deploy SSAS Tabular

Filename:       $(tool_tabular_editor)

Arguments:      "$(artifact_dir)\SSAS\Model.bim" -S "$(tool_tabular_editor_scripts_path)\SetConnectionStringFromEnv.cs" -D "Provider=MSOLAP;Data Source=$(sass_server)\$(ssas_db);" "$(ssas_catalog)" -O -C -V -E -R -M

```



Notes:

- Both steps deploy from the built `Model.bim` artifact

- `SetConnectionStringFromEnv.cs` reads release variables named `{DataSourceName}ConnectionString`

- Deploy flags used in production are `-O -C -V -E -R -M`



### Option B: XMLA Script via PowerShell (AMO / SqlServer module)



Production DW pipelines do **not** use a separate XMLA PowerShell deployment step. The real

pattern is the two TabularEditor Command Line tasks above.



### SSAS Processing Script



SSAS processing is **not** a separate pipeline script or task in the production release definition.

It is executed by the single Phase 4 SQL Agent job that runs ELT and then processes the model.



### TabularEditor Custom C# Scripts



These scripts are deployed with the TabularEditor tools package in `$(tool_tabular_editor_root)\Scripts\`.

The development source is `$(tool_tabular_editor_root)\Scripts\`.



| Script | Purpose | Inputs / Behavior | Used in |

|---|---|---|---|

| `SetConnectionStringFromEnv.cs` | Set SQL login-style provider connection strings before schema check or deploy | Reads environment variables named `{DataSourceName}ConnectionString` and applies them to matching `ProviderDataSource` objects | Release Phase 3 schema check + deploy |

| `SetADConnectionStringFromEnv.cs` | Alternative for Windows / AD impersonation deployments | Reads `service_account`, `service_account_pass`, and `{DataSourceName}ConnectionString`; sets connection string, account, password, and impersonation mode | Available for environments that need AD impersonation; not used in current pipelines |

| `ClearConnectionString.cs` | Remove real connection strings before build-time validation deploy | Replaces each provider data source connection string with the data source name placeholder | Build step 9 validation deployment |



### SSAS Deployment Conventions



- **Source of truth in git**: TMDL folder under `SSAS\{ModelName}\`

- **Release deployment artifact**: `Model.bim` built from TMDL in the build pipeline

- **Do not deploy from Visual Studio GUI or SSAS Deployment Wizard** - use TabularEditor Command Line tasks

- **Connection strings are injected at release time** by `SetConnectionStringFromEnv.cs` reading ADO release variables

- **Retain partitions on deploy** via `-R`

- **SSAS processing is not its own phase** - it is part of the same Phase 4 SQL Agent job that runs ELT



---
## 5. Power BI Report Server (PBIRS) Deployment



Three scripts cover all PBIRS deployment scenarios. All use the **`ReportingServicesTools`** PowerShell

module and Windows authentication (`-UseDefaultCredentials`).



> **Shared script path on the agent**: `$(tool_scripts)\`



---



### Script: `PBIRS-deployPbixReports.ps1` - Deploy Power BI (.pbix) Reports



Uploads `.pbix` files to PBIRS, then updates the SSAS connection string per environment.

Run this for **live-connection Power BI reports** (connected to SSAS Tabular).



```

Parameters:

  -reportPortalUri    URL of PBIRS (e.g. "https://test-reports.econ.gov.bc.ca/reports")

  -localFolderPath    Local folder containing .pbix files

  -rsFolderPath       PBIRS target folder path (e.g. "/EAO")

  -instance           SSAS server\instance (e.g. "$(sass_server)\$(ssas_db)")

  -database           SSAS database name (e.g. "$(ssas_catalog)")

  -reportsToUpdate    Optional - comma-separated list of report names to deploy

                      Omit to deploy all .pbix files in localFolderPath

  -accountName        Service account for datasource credential store (optional)

  -accountPass        Service account password (optional; mark as secret)

```



**ADO Classic Pipeline task - Deploy PBIX:**

```

Task Type:      PowerShell

Display Name:   Deploy PBIX Reports to PBIRS

Type:           File Path

File Path:      $(tool_PBIRS-deployPbixReports)

Arguments:      -reportPortalUri "$(reportPortalUri)"

                -localFolderPath "$(localFolderPath)"

                -rsFolderPath "$(rsFolderPath)"

                -instance "$(sass_server)\$(ssas_db)"

                -database "$(ssas_catalog)"

                -reportsToUpdate "$(reportsToUpdate)"

```



> **What this script does**: Uploads each `.pbix` (using `Write-RsRestCatalogItem`), then calls

> the PBIRS REST API to update the data source connection string to the environment-specific SSAS

> instance. Also tests the data source connection after update.



---



### Script: `PBIRS-deployPaginatedReports.ps1` - Deploy Paginated (.rdl) Reports



Deploys `.rdl`, `.rsd` (datasets), and `.rds` (data sources) to PBIRS. Configures the data

source with stored credentials. Verifies the connection after deployment.



```

Parameters:

  -ReportServiceHost      URI of PBIRS host (e.g. "https://prod-reports.example.gov.bc.ca")

  -ReportSourceFolder     Local folder containing .rdl/.rsd/.rds files

  -ReportDeployFolder     PBIRS target folder path

  -DatabaseConnectionString  Connection string for the data source

  -DatabaseUser           Data source username

  -DatabasePass           Data source password (mark as secret)

```



> **Important notes from script**:

> - Files are deployed in order: DataSources -> DataSets -> Reports (to preserve references)

> - Assumes a single data source per project - multi-datasource projects need manual configuration

> - Deploys with `-Overwrite` - safe to redeploy



**ADO Classic Pipeline task - Deploy Paginated Reports:**

```

Task Type:      PowerShell

Display Name:   Deploy Paginated Reports to PBIRS

Type:           File Path

Script Path:    $(tool_scripts)\PBIRS-deployPaginatedReports.ps1

Arguments:      -ReportServiceHost "$(reportPortalUri)"
                -ReportSourceFolder "$(System.DefaultWorkingDirectory)\$(Release.PrimaryArtifactSourceAlias)\PaginatedReports\"

                -ReportDeployFolder "$(rsFolderPath)"

                -DatabaseConnectionString "$(DW_CONNECTION_STRING)"

                -DatabaseUser "$(DB_USER)"

                -DatabasePass "$(DB_PASS)"

```



---



### Script: `PBIRS-updateConnection.ps1` - Update Connection String Only



Updates the SSAS connection string for reports already deployed to PBIRS. Use this when

the PBIRS report does not need to be re-uploaded (file unchanged) but the target SSAS

server/database has changed (e.g., post-restore or environment reconfiguration).



```

Parameters:

  -reportPortalUri    URL of PBIRS

  -localFolderPath    Local folder (used only for reference - not re-uploaded)

  -rsFolderPath       PBIRS folder path (include trailing /)

  -instance           SSAS server\instance

  -database           SSAS database

  -reportsToUpdate    Mandatory - comma-separated list of specific report names to update

  -accountName        Service account (optional)

  -accountPass        Service account password (optional)

```



---



### PBIRS Deployment Conventions



- **Live connection `.pbix` reports** contain no embedded data - only SSAS connection metadata

- **Ordered deployment**: SSAS model must be deployed and processed before PBIRS reports

- **Connection string format**: `Data Source=<server>;Initial Catalog=<database>;Cube=Model`

- **TLS 1.2**: The PBIRS scripts force `[Net.ServicePointManager]::SecurityProtocol = Tls12`

  - required because PBIRS servers may default to TLS 1.0

- **`ReportingServicesTools` module** must be installed on the build/release agent

- **Naming**: PBIX file name = report name in PBIRS - use consistent file naming across environments

- **PBIRS folder structure** mirrors environment, set via `$(rsFolderPath)` variable group variable:

  - Dev: `/Reports/Dev`, Test: `/Reports/Test`, Prod: `/Reports`



---

---

> **See also:** [devops-operations-patterns.md](devops-operations-patterns.md) - ELT pipeline trigger, PowerShell script standards, repository structure, shared script library, Tabular Editor tools package, ALM Toolkit workflow, and incident response (roll-forward philosophy).
