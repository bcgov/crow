<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# SSISDB Catalog Configuration Reference

This is the authoritative reference for SSIS Catalog (SSISDB) configuration for Data Warehouse delivery. Use it for Skill Mode K (SSIS Catalog Configuration), Mode G (DevOps Deployment Review), Mode M (ADO Pipeline Config), and Mode N (Full Orchestrated Build).

## Organisation conventions

- Database schemas: `Dimension`, `Fact`, `Staging`, `Internal`, `SSAS` for views, `Security`, `Snapshots`.
- Do not use table prefixes. Always use schema-qualified names such as `Dimension.Customer` and `Fact.Sales`.
- Surrogate keys use `{EntityName}Key`, for example `CustomerKey`.
- Natural keys sourced from systems use `_Source{OriginalName}`, for example `_SourceCustomerId`.
- Load stored procedures use `Schema.Load{Entity}`, for example `Dimension.LoadCustomer` or `Fact.LoadSales`.
- Deployment environments are `DEV`, `TEST`, `UAT`, `PROD`, and `SUPPORT`.
- `SUPPORT` mirrors `PROD` variable values.
- Security uses AD groups only.
- SSAS projects must have two roles: `{Name} Consumers` with Read permission and `{Name} Authors` with Read and Process permissions.
- Pipelines are ADO Classic pipelines on Azure DevOps Server on-premises.
- Approved tools are Visual Studio DB Projects, Git, Tabular Editor 2.x, SSMS, BIML Express, DAX Studio, ALM Toolkit, Power BI Desktop Report Server edition, and Azure DevOps Server.

## SSISDB topology

SSISDB is organised as:

```text
SSIS Catalog
└── Folders
    └── Projects
        └── Environment references
    └── Environments
        └── Variables
```

Use one SSISDB folder per DW project, for example `EAO_DW`. Deploy all SSIS projects for that DW into the folder. Create one SSISDB environment per deployment environment in the same folder:

- `DEV`
- `TEST`
- `UAT`
- `PROD`
- `SUPPORT`

Each deployed project is linked to the target environment by an environment reference. Always use a relative reference because the project and environment must be in the same SSISDB folder.

`SUPPORT` is a separate environment in the same folder and clones `PROD` variable values. It exists for production-support investigation, not routine release deployment.

## Standard environment variable schema

Every SSIS project must define the following variables in every SSISDB environment.

| Variable name | Type | Sensitive | Purpose |
|---|---|---:|---|
| `ssis_param_LoadType` | String | No | `I` incremental or `F` full. Default is `I`. |
| `ssis_param_SourceServer` | String | No | Source OLTP or source system server name. |
| `ssis_param_SourceDB` | String | No | Source database name. |
| `ssis_param_TargetServer` | String | No | DW SQL Server instance. |
| `ssis_param_TargetDB` | String | No | DW database name. |
| `ssis_param_LogServer` | String | No | Server hosting `Internal.Lineage`, usually same as `ssis_param_TargetServer`. |
| `ssis_param_LogDB` | String | No | Database hosting `Internal.Lineage`, usually same as `ssis_param_TargetDB`. |

### Additional project-specific variables

Add these only when the project needs them:

| Variable name | Type | Sensitive | Purpose |
|---|---|---:|---|
| `ssis_param_SourceConnectionString` | String | Depends | Full OLE DB connection string for source. Mark sensitive if it contains a password. |
| `ssis_param_DWConnectionString` | String | Depends | Full OLE DB connection string for the DW target. Mark sensitive if it contains a password. |

### Salesforce variables for KingswaySoft projects

When using KingswaySoft for Salesforce integration, add:

| Variable name | Type | Sensitive | Purpose |
|---|---|---:|---|
| `ssis_param_SFUsername` | String | No | Salesforce integration username. |
| `ssis_param_SFPassword` | String | Yes | Salesforce password. |
| `ssis_param_SFSecurityToken` | String | Yes | Salesforce security token. |

## Sensitive vs non-sensitive rules

### Non-sensitive values

These values are not sensitive and may be stored in tokenised `ssis_catalog_configuration.json`:

- Server names.
- Database names.
- Load types such as `I` or `F`.
- Windows or AD group names.
- Environment names such as `DEV`, `TEST`, `UAT`, `PROD`, `SUPPORT`.

### Sensitive values

These values are sensitive:

- Passwords.
- Security tokens.
- Connection strings containing passwords.
- Any value that grants direct access to a source, target, or third-party system.

Sensitive values must be stored as secret variables in Azure DevOps Server variable groups or release variables. Do not store plain-text secret values in `ssis_catalog_configuration.json`.

In tokenised JSON, represent sensitive values with a Replace Tokens token. The token is replaced at deploy time before the Configure SSIS Catalog task runs.

```json
{
  "name": "ssis_param_SFPassword",
  "type": "String",
  "sensitive": true,
  "value": "#{sf_password}#"
}
```

The ADO Classic release stage must provide `sf_password` as a secret variable. The Replace Tokens task resolves `#{sf_password}#` before the Configure SSIS Catalog marketplace task reads the JSON.

## ssis_catalog_configuration.json format

The Configure SSIS Catalog marketplace task consumes the following JSON structure. The `#{...}#` values are tokens replaced by the ADO Replace Tokens task before Configure SSIS Catalog runs.

```json
{
  "folders": [
    {
      "name": "{ProjectName}",
      "projects": [
        {
          "name": "{SsisProjectName}",
          "environment_references": [
            { "environment_name": "#{environment_name}#", "reference_type": "relative" }
          ],
          "parameters": []
        }
      ],
      "environments": [
        {
          "name": "#{environment_name}#",
          "variables": [
            { "name": "ssis_param_LoadType", "type": "String", "sensitive": false, "value": "I" },
            { "name": "ssis_param_TargetServer", "type": "String", "sensitive": false, "value": "#{db_server}#" },
            { "name": "ssis_param_TargetDB", "type": "String", "sensitive": false, "value": "#{dw_db_catalog}#" }
          ]
        }
      ]
    }
  ]
}
```

A complete project normally includes all standard variables:

```json
{
  "folders": [
    {
      "name": "EAO_DW",
      "projects": [
        {
          "name": "EAO_DW_ETL",
          "environment_references": [
            { "environment_name": "#{environment_name}#", "reference_type": "relative" }
          ],
          "parameters": []
        }
      ],
      "environments": [
        {
          "name": "#{environment_name}#",
          "variables": [
            { "name": "ssis_param_LoadType", "type": "String", "sensitive": false, "value": "#{load_type}#" },
            { "name": "ssis_param_SourceServer", "type": "String", "sensitive": false, "value": "#{source_server}#" },
            { "name": "ssis_param_SourceDB", "type": "String", "sensitive": false, "value": "#{source_db_catalog}#" },
            { "name": "ssis_param_TargetServer", "type": "String", "sensitive": false, "value": "#{db_server}#" },
            { "name": "ssis_param_TargetDB", "type": "String", "sensitive": false, "value": "#{dw_db_catalog}#" },
            { "name": "ssis_param_LogServer", "type": "String", "sensitive": false, "value": "#{db_server}#" },
            { "name": "ssis_param_LogDB", "type": "String", "sensitive": false, "value": "#{dw_db_catalog}#" },
            { "name": "ssis_param_SourceConnectionString", "type": "String", "sensitive": true, "value": "#{source_connection_string}#" },
            { "name": "ssis_param_DWConnectionString", "type": "String", "sensitive": false, "value": "Data Source=#{db_server}#;Initial Catalog=#{dw_db_catalog}#;Provider=SQLNCLI11.1;Integrated Security=SSPI;Auto Translate=False;" }
          ]
        }
      ]
    }
  ]
}
```

## Project-to-environment reference mapping

### SSMS UI steps

1. Open SSMS and connect to the SQL Server instance hosting SSISDB.
2. Expand Integration Services Catalogs, then expand SSISDB.
3. Expand the DW project folder, for example `EAO_DW`.
4. Confirm the environment exists under Environments, for example `DEV`.
5. Expand Projects and right-click the SSIS project, for example `EAO_DW_ETL`.
6. Select Configure.
7. On References, add the environment.
8. Select reference type `Relative`.
9. Confirm the project parameters are bound to the environment variables.

### T-SQL reference creation

Use `catalog.create_environment_reference` when scripting the reference. Use reference type `R` for relative references.

```sql
DECLARE @ReferenceId BIGINT;

EXEC SSISDB.catalog.create_environment_reference
    @folder_name = N'EAO_DW',
    @project_name = N'EAO_DW_ETL',
    @environment_name = N'DEV',
    @reference_type = N'R',
    @reference_id = @ReferenceId OUTPUT;

SELECT @ReferenceId AS EnvironmentReferenceId;
```

Relative references are mandatory because projects and environments are deployed into the same SSISDB folder. Do not use absolute references for standard DW deployments.

### PowerShell alternative

The marketplace task is preferred. If a scripted alternative is required, create the folder, environment, variables, and reference using T-SQL executed from PowerShell.

```powershell
$server = "DW-SQL-DEV"
$folderName = "EAO_DW"
$projectName = "EAO_DW_ETL"
$environmentName = "DEV"

$sql = @"
IF NOT EXISTS (SELECT 1 FROM SSISDB.catalog.folders WHERE name = N'$folderName')
BEGIN
    EXEC SSISDB.catalog.create_folder @folder_name = N'$folderName';
END;

IF NOT EXISTS (
    SELECT 1
    FROM SSISDB.catalog.environments e
    JOIN SSISDB.catalog.folders f ON e.folder_id = f.folder_id
    WHERE f.name = N'$folderName' AND e.name = N'$environmentName'
)
BEGIN
    EXEC SSISDB.catalog.create_environment
        @folder_name = N'$folderName',
        @environment_name = N'$environmentName';
END;

IF NOT EXISTS (
    SELECT 1
    FROM SSISDB.catalog.environment_variables v
    JOIN SSISDB.catalog.environments e ON v.environment_id = e.environment_id
    JOIN SSISDB.catalog.folders f ON e.folder_id = f.folder_id
    WHERE f.name = N'$folderName'
      AND e.name = N'$environmentName'
      AND v.name = N'ssis_param_LoadType'
)
BEGIN
    EXEC SSISDB.catalog.create_environment_variable
        @folder_name = N'$folderName',
        @environment_name = N'$environmentName',
        @variable_name = N'ssis_param_LoadType',
        @data_type = N'String',
        @sensitive = 0,
        @value = N'I';
END;

IF EXISTS (
    SELECT 1
    FROM SSISDB.catalog.projects p
    JOIN SSISDB.catalog.folders f ON p.folder_id = f.folder_id
    WHERE f.name = N'$folderName' AND p.name = N'$projectName'
)
AND NOT EXISTS (
    SELECT 1
    FROM SSISDB.catalog.environment_references r
    JOIN SSISDB.catalog.projects p ON r.project_id = p.project_id
    JOIN SSISDB.catalog.folders f ON p.folder_id = f.folder_id
    WHERE f.name = N'$folderName'
      AND p.name = N'$projectName'
      AND r.environment_name = N'$environmentName'
      AND r.reference_type = N'R'
)
BEGIN
    DECLARE @ReferenceId BIGINT;
    EXEC SSISDB.catalog.create_environment_reference
        @folder_name = N'$folderName',
        @project_name = N'$projectName',
        @environment_name = N'$environmentName',
        @reference_type = N'R',
        @reference_id = @ReferenceId OUTPUT;
END;
"@

Invoke-Sqlcmd -ServerInstance $server -Database "SSISDB" -Query $sql
```

## Parameter binding

### Project-level and package-level parameters

Use project-level parameters for values shared by packages, especially connection strings and common load settings. Use package-level parameters only when a value is genuinely package-specific.

Recommended project-level parameters:

- `ssis_param_LoadType`
- `ssis_param_SourceConnectionString`
- `ssis_param_DWConnectionString`
- `ssis_param_SourceServer`
- `ssis_param_SourceDB`
- `ssis_param_TargetServer`
- `ssis_param_TargetDB`
- `ssis_param_LogServer`
- `ssis_param_LogDB`

OLE DB connection managers should be parameterised by expression. The connection manager connection string expression reads a project parameter, and the project parameter is bound to an SSISDB environment variable.

Example flow:

```text
SSISDB environment variable
ssis_param_DWConnectionString
        ↓
Project parameter
ssis_param_DWConnectionString
        ↓
OLE DB connection manager ConnectionString expression
        ↓
Packages loading Dimension.Customer, Fact.Sales, Staging.CustomerExtract, and Internal.Lineage
```

### T-SQL binding pattern

Use `catalog.set_object_parameter_value` to bind a parameter to an environment variable. Use object type `20` for project parameters and `30` for package parameters. Use value type `R` when referencing an environment variable.

```sql
EXEC SSISDB.catalog.set_object_parameter_value
    @folder_name = N'EAO_DW',
    @project_name = N'EAO_DW_ETL',
    @object_type = 20,
    @parameter_name = N'ssis_param_DWConnectionString',
    @parameter_value = N'ssis_param_DWConnectionString',
    @value_type = N'R';

EXEC SSISDB.catalog.set_object_parameter_value
    @folder_name = N'EAO_DW',
    @project_name = N'EAO_DW_ETL',
    @object_type = 20,
    @parameter_name = N'ssis_param_LoadType',
    @parameter_value = N'ssis_param_LoadType',
    @value_type = N'R';
```

In a correctly configured ADO Classic release pipeline, the SSIS deployment task and Configure SSIS Catalog task handle references, variables, and parameter bindings declaratively through the tokenised JSON. Manual T-SQL should only be used for investigation, repair, or controlled one-off administration.

## Operation log retention

Set SSISDB catalog properties after SSISDB creation and review them during platform maintenance.

Recommended values:

- `RETENTION_WINDOW` is `90` days in `PROD`.
- `RETENTION_WINDOW` is `30` days in `DEV`, `TEST`, and `UAT`.
- `SUPPORT` should follow `PROD` retention when it is hosted on a production-support SSISDB instance.
- `MAX_CONCURRENT_EXECUTABLES` should normally remain `-1` so SSIS uses the server default based on logical processors. Set a fixed value only when agreed for capacity management.

```sql
-- PROD and SUPPORT production-support instances
EXEC SSISDB.catalog.configure_catalog
    @property_name = N'RETENTION_WINDOW',
    @property_value = 90;

EXEC SSISDB.catalog.configure_catalog
    @property_name = N'MAX_CONCURRENT_EXECUTABLES',
    @property_value = -1;

-- DEV, TEST, and UAT instances
EXEC SSISDB.catalog.configure_catalog
    @property_name = N'RETENTION_WINDOW',
    @property_value = 30;

EXEC SSISDB.catalog.configure_catalog
    @property_name = N'MAX_CONCURRENT_EXECUTABLES',
    @property_value = -1;
```

Verify current settings:

```sql
SELECT property_name, property_value
FROM SSISDB.catalog.catalog_properties
WHERE property_name IN (N'RETENTION_WINDOW', N'MAX_CONCURRENT_EXECUTABLES')
ORDER BY property_name;
```

## SUPPORT environment handling

`SUPPORT` is an additional environment in the same SSISDB folder. It must mirror `PROD` variable values exactly, including source, target, logging, and connection configuration.

Rules:

- Create environment name `SUPPORT` in the same SSISDB folder as `DEV`, `TEST`, `UAT`, and `PROD`.
- Use the same variable values as `PROD`.
- Use the same ADO variable group values as the `PROD` stage.
- Use a separate ADO Classic release stage named `SUPPORT`.
- Require manual approval for the `SUPPORT` stage.
- Do not auto-deploy `SUPPORT` on every release.
- Use `SUPPORT` for production-support investigations and controlled reconfiguration only.

Example environment entries in JSON:

```json
{
  "environments": [
    {
      "name": "PROD",
      "variables": [
        { "name": "ssis_param_LoadType", "type": "String", "sensitive": false, "value": "I" },
        { "name": "ssis_param_TargetServer", "type": "String", "sensitive": false, "value": "#{prod_db_server}#" },
        { "name": "ssis_param_TargetDB", "type": "String", "sensitive": false, "value": "#{prod_dw_db_catalog}#" }
      ]
    },
    {
      "name": "SUPPORT",
      "variables": [
        { "name": "ssis_param_LoadType", "type": "String", "sensitive": false, "value": "I" },
        { "name": "ssis_param_TargetServer", "type": "String", "sensitive": false, "value": "#{prod_db_server}#" },
        { "name": "ssis_param_TargetDB", "type": "String", "sensitive": false, "value": "#{prod_dw_db_catalog}#" }
      ]
    }
  ]
}
```

## Validation queries

Run these queries in SSMS after deployment.

### Verify folder, project, and environment exist

```sql
SELECT f.Name AS Folder, p.Name AS Project, e.Name AS Environment
FROM SSISDB.catalog.folders f
JOIN SSISDB.catalog.projects p ON f.folder_id = p.folder_id
JOIN SSISDB.catalog.environments e ON f.folder_id = e.folder_id
WHERE f.Name = N'{ProjectName}'
ORDER BY f.Name, p.Name, e.Name;
```

### Verify environment variable values

Sensitive values are redacted.

```sql
SELECT v.Name, v.Type, v.Sensitive, CASE v.Sensitive WHEN 1 THEN '***' ELSE CAST(v.Value AS NVARCHAR(500)) END AS Value
FROM SSISDB.catalog.environment_variables v
JOIN SSISDB.catalog.environments e ON v.environment_id = e.environment_id
JOIN SSISDB.catalog.folders f ON e.folder_id = f.folder_id
WHERE f.Name = N'{ProjectName}' AND e.Name = N'{EnvironmentName}'
ORDER BY v.Name;
```

### Verify project environment references

```sql
SELECT
    f.name AS Folder,
    p.name AS Project,
    r.environment_name AS Environment,
    CASE r.reference_type WHEN 'R' THEN 'relative' WHEN 'A' THEN 'absolute' ELSE r.reference_type END AS ReferenceType
FROM SSISDB.catalog.environment_references r
JOIN SSISDB.catalog.projects p ON r.project_id = p.project_id
JOIN SSISDB.catalog.folders f ON p.folder_id = f.folder_id
WHERE f.name = N'{ProjectName}'
ORDER BY f.name, p.name, r.environment_name;
```

### Verify parameter bindings

```sql
SELECT
    f.name AS Folder,
    p.name AS Project,
    op.object_type,
    op.parameter_name,
    op.value_type,
    op.referenced_variable_name
FROM SSISDB.catalog.object_parameters op
JOIN SSISDB.catalog.projects p ON op.project_id = p.project_id
JOIN SSISDB.catalog.folders f ON p.folder_id = f.folder_id
WHERE f.name = N'{ProjectName}'
  AND p.name = N'{SsisProjectName}'
ORDER BY op.object_type, op.parameter_name;
```

## Review checklist

Use this checklist when reviewing SSIS Catalog configuration:

- One SSISDB folder exists per DW project, for example `EAO_DW`.
- Environments are exactly `DEV`, `TEST`, `UAT`, `PROD`, and `SUPPORT` where applicable.
- `SUPPORT` mirrors `PROD` and is manually approved.
- Environment references are relative.
- All standard variables exist in every environment.
- Secret values are marked sensitive and supplied by secret ADO variables.
- `ssis_catalog_configuration.json` contains tokens, not plain-text secrets.
- Project parameters are bound to environment variables.
- Connection managers use project parameters for OLE DB connection strings.
- Operation log retention is 90 days for `PROD` and 30 days for non-production.
- DW object examples follow organisation naming conventions such as `Dimension.Customer`, `Fact.Sales`, `Staging.CustomerExtract`, and `Internal.Lineage`.
