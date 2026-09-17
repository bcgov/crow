<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# SSDT Database Project Structure Reference

**Scope:** Authoritative project-structure reference for Visual Studio SSDT Database Projects used for DW schema artifacts in this organisation. Applies to GitHub Copilot Skill Mode H (DW Schema Scaffold), Mode N (Full Orchestrated Build), and Mode G (DevOps Deployment Review).

**Core conventions:** Schemas classify objects: `Dimension`, `Fact`, `Staging`, `Internal`, `SSAS`, `Security`, `Snapshots`. Do not use table prefixes such as `Dim`, `Fact`, or `Stg`. Use `Dimension.Customer`; the schema, not the object name, carries the classification. There is no ODS layer.

## 1. Project file (.sqlproj) setup

### Target and output

- Use a Visual Studio SQL Server Database Project (`.sqlproj`).
- Target platform: SQL Server 2019 or SQL Server 2022.
- Output type: Database project producing a DACPAC.
- Add SSDT system database references to `master.dacpac` and `msdb.dacpac` when using system objects, SQL Agent metadata, or database mail references.
- Set compatibility to match the estate: 150 for SQL Server 2019, 160 for SQL Server 2022.

### Key `.sqlproj` XML template

```xml
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <Name>EAO_DW</Name>
    <ProjectGuid>{00000000-0000-0000-0000-000000000000}</ProjectGuid>
    <DSP>Microsoft.Data.Tools.Schema.Sql.Sql160DatabaseSchemaProvider</DSP>
    <ModelCollation>1033, CI</ModelCollation>
    <DefaultCollation>SQL_Latin1_General_CP1_CI_AS</DefaultCollation>
    <TargetDatabaseSet>True</TargetDatabaseSet>
    <DefaultFileStructure>BySchemaAndSchemaType</DefaultFileStructure>
    <OutputType>Database</OutputType>
    <TargetFrameworkVersion>v4.7.2</TargetFrameworkVersion>
    <SqlServerVerification>False</SqlServerVerification>
    <TargetPlatform>SQL Server 2022</TargetPlatform>
    <CompatibilityMode>160</CompatibilityMode>
  </PropertyGroup>

  <!-- For SQL Server 2019 use:
       <DSP>Microsoft.Data.Tools.Schema.Sql.Sql150DatabaseSchemaProvider</DSP>
       <TargetPlatform>SQL Server 2019</TargetPlatform>
       <CompatibilityMode>150</CompatibilityMode>
  -->

  <ItemGroup>
    <ArtifactReference Include="$(DacPacRootPath)\Extensions\Microsoft\SQLDB\Extensions\SqlServer\160\SqlSchemas\master.dacpac">
      <HintPath>$(DacPacRootPath)\Extensions\Microsoft\SQLDB\Extensions\SqlServer\160\SqlSchemas\master.dacpac</HintPath>
      <SuppressMissingDependenciesErrors>False</SuppressMissingDependenciesErrors>
      <DatabaseVariableLiteralValue>master</DatabaseVariableLiteralValue>
    </ArtifactReference>
    <ArtifactReference Include="$(DacPacRootPath)\Extensions\Microsoft\SQLDB\Extensions\SqlServer\160\SqlSchemas\msdb.dacpac">
      <HintPath>$(DacPacRootPath)\Extensions\Microsoft\SQLDB\Extensions\SqlServer\160\SqlSchemas\msdb.dacpac</HintPath>
      <SuppressMissingDependenciesErrors>False</SuppressMissingDependenciesErrors>
      <DatabaseVariableLiteralValue>msdb</DatabaseVariableLiteralValue>
    </ArtifactReference>
  </ItemGroup>
</Project>
```

## 2. Solution structure

### Standard layout

One `.sqlproj` exists per DW database. The `.sln` file lives at the git root or one level below the git root if the repository contains multiple products. Prefer git root for a single DW solution.

```text
GitRoot\
  EAO_DW.sln
  EAO_DW\
    EAO_DW.sqlproj
    Dimension\
    Fact\
    Staging\
    Internal\
    SSAS\
    Security\
    Snapshots\
    Scripts\
  SharedCalendar\              ? optional shared reference project
    SharedCalendar.sqlproj
```

### Composite project references

If a shared Calendar or reference-data project exists, reference its DACPAC as a composite project reference. Shared objects must still follow org conventions, for example `Dimension.Calendar`.

```xml
<ItemGroup>
  <ProjectReference Include="..\SharedCalendar\SharedCalendar.sqlproj">
    <Name>SharedCalendar</Name>
    <Project>{11111111-1111-1111-1111-111111111111}</Project>
    <Private>True</Private>
    <SuppressMissingDependenciesErrors>False</SuppressMissingDependenciesErrors>
    <DatabaseVariableLiteralValue>EAO_DW</DatabaseVariableLiteralValue>
  </ProjectReference>
</ItemGroup>
```

## 3. Folder structure (canonical)

The project is organised by schema, then object type. `SSAS` contains views only. `Snapshots` are not built into the DACPAC unless explicitly modelled as database objects.

```text
Dimension\
  Tables\
  Stored Procedures\
  Views\         ? rarely used; SSAS views live in SSAS\ not here
Fact\
  Tables\
  Stored Procedures\
Staging\
  Tables\
  Stored Procedures\
Internal\
  Tables\        ? Internal.Lineage, Internal.IncrementalLoads, Internal.LastUpdatedSource
  Stored Procedures\
  Functions\
SSAS\
  Views\         ? ALL partition source views live here; column aliases Title Case with spaces
Security\
  Roles\         ? db-level roles (not SSAS roles)
  Schemas\
Snapshots\
  Tables\
Scripts\
  PreDeploy\     ? PreDeployment.sql (single entry point using :r includes)
  PostDeploy\    ? PostDeployment.sql (single entry point using :r includes)
  SeedData\      ? idempotent MERGE statements for reference/seed data
  ExtendedProperties\ ? sp_addextendedproperty scripts, organised by schema
```

### Schema object examples

```sql
CREATE SCHEMA [Dimension];
GO
CREATE SCHEMA [Fact];
GO
CREATE SCHEMA [Staging];
GO
CREATE SCHEMA [Internal];
GO
CREATE SCHEMA [SSAS];
GO
CREATE SCHEMA [Security];
GO
CREATE SCHEMA [Snapshots];
GO
```

## 4. File naming convention

### Object files

- Use one SQL file per object.
- File name matches the object name without the schema prefix.
- Do not prefix table names with schema abbreviations.
- Surrogate key: `{EntityName}Key`, for example `CustomerKey`.
- Natural key: `_Source{OriginalName}`, for example `_SourceCustomerID`.
- Date dimension is always `Dimension.Calendar`.
- Staging tables include `LineageKey INT NULL` linked to `Internal.Lineage`.
- Load stored procedures use `Schema.Load{Entity}`, for example `Staging.LoadCustomer` and `Dimension.LoadCustomer`.

```text
Dimension\Tables\Customer.sql              ? [Dimension].[Customer]
Dimension\Tables\Calendar.sql              ? [Dimension].[Calendar]
Fact\Tables\Sales.sql                       ? [Fact].[Sales]
Staging\Tables\Customer.sql                 ? [Staging].[Customer]
Staging\Stored Procedures\LoadCustomer.sql  ? [Staging].[LoadCustomer]
Dimension\Stored Procedures\LoadCustomer.sql ? [Dimension].[LoadCustomer]
Internal\Tables\Lineage.sql                 ? [Internal].[Lineage]
SSAS\Views\Customer.sql                     ? [SSAS].[Customer] feeding SSAS table Customer
```

### Table and SSAS view templates

```sql
CREATE TABLE [Dimension].[Customer]
(
    [CustomerKey] INT IDENTITY(1,1) NOT NULL,
    [_SourceCustomerID] NVARCHAR(50) NOT NULL,
    [CustomerName] NVARCHAR(200) NOT NULL,
    [IsCurrent] BIT NOT NULL CONSTRAINT [DF_Dimension_Customer_IsCurrent] DEFAULT (1),
    [LineageKey] INT NULL,
    CONSTRAINT [PK_Dimension_Customer] PRIMARY KEY CLUSTERED ([CustomerKey])
);
GO
```

```sql
CREATE TABLE [Staging].[Customer]
(
    [_SourceCustomerID] NVARCHAR(50) NOT NULL,
    [CustomerName] NVARCHAR(200) NULL,
    [LineageKey] INT NULL
);
GO
```

```sql
CREATE VIEW [SSAS].[Customer]
AS
SELECT
    [CustomerKey] AS [Customer Key],
    [_SourceCustomerID] AS [Source Customer ID],
    [CustomerName] AS [Customer Name]
FROM [Dimension].[Customer]
WHERE [IsCurrent] = 1;
GO
```

## 5. Build actions

### Required build actions

- `Build` - all `.sql` object files that define database objects.
- `None` - snapshot files, reference data source files, generated deployment scripts, and documentation.
- `PreDeploy` - exactly one file: `Scripts\PreDeploy\PreDeployment.sql`.
- `PostDeploy` - exactly one file: `Scripts\PostDeploy\PostDeployment.sql`.

### `.sqlproj` build-action template

```xml
<ItemGroup>
  <Build Include="Dimension\Tables\Customer.sql" />
  <Build Include="Dimension\Tables\Calendar.sql" />
  <Build Include="Fact\Tables\Sales.sql" />
  <Build Include="Staging\Tables\Customer.sql" />
  <Build Include="Internal\Tables\Lineage.sql" />
  <Build Include="SSAS\Views\Customer.sql" />
  <Build Include="Security\Roles\DWReader.sql" />

  <None Include="Snapshots\Tables\Sales_2024_12.sql" />
  <None Include="Scripts\SeedData\Calendar.sql" />
  <None Include="README.md" />

  <PreDeploy Include="Scripts\PreDeploy\PreDeployment.sql" />
  <PostDeploy Include="Scripts\PostDeploy\PostDeployment.sql" />
</ItemGroup>
```

## 6. Pre/Post-deploy script patterns

### `PreDeployment.sql`

`PreDeployment.sql` is the only `PreDeploy` build action. It composes smaller scripts with SQLCMD `:r` includes. Pre-deploy is for safe preparation only: no destructive business-data changes.

```sql
:setvar DisableLoadConstraints "0"

PRINT 'PreDeployment: starting';

:r .\PrepareDeployment.sql
:r .\DisableLoadConstraints.sql

PRINT 'PreDeployment: complete';
GO
```

### Disabling constraints during controlled load windows

Use this only when the pipeline explicitly sets a SQLCMD variable for a controlled load or backfill. Re-enable and validate constraints in the load process.

```sql
IF '$(DisableLoadConstraints)' = '1'
BEGIN
    PRINT 'Disabling selected Fact constraints for controlled load window';

    ALTER TABLE [Fact].[Sales] NOCHECK CONSTRAINT [FK_Fact_Sales_Customer];
    ALTER TABLE [Fact].[Sales] NOCHECK CONSTRAINT [FK_Fact_Sales_Calendar];
END;
GO
```

### `PostDeployment.sql`

`PostDeployment.sql` is the only `PostDeploy` build action. Use `:r` includes for seed data, internal audit rows, extended properties, and security grants.

```sql
PRINT 'PostDeployment: starting';

:r ..\SeedData\Calendar.sql
:r .\InternalAuditObjects.sql
:r ..\ExtendedProperties\Dimension\Customer.sql
:r ..\ExtendedProperties\Fact\Sales.sql
:r .\GrantSchemaPermissions.sql

PRINT 'PostDeployment: complete';
GO
```

### Idempotent post-deploy examples

Every post-deploy script must be safe to re-run. Use `IF NOT EXISTS`, `MERGE`, or `IF @@ROWCOUNT = 0`.

```sql
IF NOT EXISTS (SELECT 1 FROM [Dimension].[Calendar])
BEGIN
    INSERT INTO [Dimension].[Calendar] ([DateKey], [Date], [CalendarYear], [CalendarMonth])
    SELECT [DateKey], [Date], [CalendarYear], [CalendarMonth]
    FROM [Internal].[CalendarSeedSource];
END;
GO
```

```sql
MERGE [Internal].[Lineage] AS tgt
USING (VALUES ('SSDT Publish', SYSUTCDATETIME())) AS src ([ProcessName], [StartedAtUtc])
    ON tgt.[ProcessName] = src.[ProcessName]
WHEN NOT MATCHED THEN
    INSERT ([ProcessName], [StartedAtUtc])
    VALUES (src.[ProcessName], src.[StartedAtUtc]);
GO

MERGE [Internal].[IncrementalLoads] AS tgt
USING (VALUES ('Customer', CONVERT(DATETIME2(0), '19000101'))) AS src ([EntityName], [LastLoadedAtUtc])
    ON tgt.[EntityName] = src.[EntityName]
WHEN NOT MATCHED THEN
    INSERT ([EntityName], [LastLoadedAtUtc])
    VALUES (src.[EntityName], src.[LastLoadedAtUtc]);
GO

MERGE [Internal].[LastUpdatedSource] AS tgt
USING (VALUES ('Customer', NULL)) AS src ([EntityName], [LastUpdatedAtSource])
    ON tgt.[EntityName] = src.[EntityName]
WHEN NOT MATCHED THEN
    INSERT ([EntityName], [LastUpdatedAtSource])
    VALUES (src.[EntityName], src.[LastUpdatedAtSource]);
GO
```

```sql
IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_permissions p
    JOIN sys.database_principals r ON p.grantee_principal_id = r.principal_id
    JOIN sys.schemas s ON p.major_id = s.schema_id
    WHERE r.name = 'DWReader'
      AND s.name = 'SSAS'
      AND p.permission_name = 'SELECT'
)
BEGIN
    GRANT SELECT ON SCHEMA::[SSAS] TO [DWReader];
END;
GO
```

## 7. SQLCMD variables

### Standard variables

Use the same SQLCMD variable names across `.sqlproj`, `.sql` files, publish profiles, and ADO pipeline variables.

| Variable | Purpose |
|---|---|
| `$(SourceServer)` | Source system server. |
| `$(SourceDB)` | Source system database. |
| `$(DWServer)` | Target DW SQL Server. |
| `$(DWDB)` | Target DW database/catalog. |
| `$(SSASServer)` | SSAS Tabular server used by post-deploy or metadata steps. |
| `$(SSASCatalog)` | SSAS Tabular database/catalog name. |

### `.sqlproj` variable declarations

```xml
<ItemGroup>
  <SqlCmdVariable Include="SourceServer"><DefaultValue>DEV-SQL</DefaultValue></SqlCmdVariable>
  <SqlCmdVariable Include="SourceDB"><DefaultValue>Source_DEV</DefaultValue></SqlCmdVariable>
  <SqlCmdVariable Include="DWServer"><DefaultValue>DEV-DW-SQL</DefaultValue></SqlCmdVariable>
  <SqlCmdVariable Include="DWDB"><DefaultValue>EAO_DW_DEV</DefaultValue></SqlCmdVariable>
  <SqlCmdVariable Include="SSASServer"><DefaultValue>DEV-SSAS</DefaultValue></SqlCmdVariable>
  <SqlCmdVariable Include="SSASCatalog"><DefaultValue>EAO_Tabular_DEV</DefaultValue></SqlCmdVariable>
</ItemGroup>
```

### Use in `.sql` files

```sql
PRINT 'Publishing $(DWDB) on $(DWServer)';
PRINT 'Source system: $(SourceServer).$(SourceDB)';
PRINT 'SSAS target: $(SSASServer).$(SSASCatalog)';
GO
```

### Use in `.publish.xml`

```xml
<ItemGroup>
  <SqlCmdVariable Include="SourceServer">
    <Value>$(source_server)</Value>
  </SqlCmdVariable>
  <SqlCmdVariable Include="SourceDB">
    <Value>$(source_db)</Value>
  </SqlCmdVariable>
  <SqlCmdVariable Include="DWServer">
    <Value>$(db_server)</Value>
  </SqlCmdVariable>
  <SqlCmdVariable Include="DWDB">
    <Value>$(dw_db_catalog)</Value>
  </SqlCmdVariable>
  <SqlCmdVariable Include="SSASServer">
    <Value>$(sass_server)</Value>
  </SqlCmdVariable>
  <SqlCmdVariable Include="SSASCatalog">
    <Value>$(ssas_catalog)</Value>
  </SqlCmdVariable>
</ItemGroup>
```

## 8. Publish profiles (.publish.xml) - one per environment

Publish profiles provide dev-time defaults. Azure DevOps Server pipelines override connection strings and SQLCMD values with `$(db_server)`, `$(dw_db_catalog)`, and environment-specific variable groups. SUPPORT mirrors PROD values but targets the SUPPORT catalog/server allocation.

### Option differences by environment

| Environment | BlockOnPossibleDataLoss | DropObjectsNotInSource | IgnorePermissions |
|---|---:|---:|---:|
| DEV | false | false | true |
| TEST | false | false | true |
| UAT | true | false | false |
| PROD | true | false | false |
| SUPPORT | true | false | false |

### DEV.publish.xml

```xml
<Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <TargetDatabaseName>EAO_DW_DEV</TargetDatabaseName>
    <TargetConnectionString>Data Source=$(db_server);Initial Catalog=$(dw_db_catalog);Integrated Security=True;TrustServerCertificate=True</TargetConnectionString>
    <DeployScriptFileName>EAO_DW_DEV.sql</DeployScriptFileName>
    <DeployReportFileName>EAO_DW_DEV.xml</DeployReportFileName>
    <BlockOnPossibleDataLoss>False</BlockOnPossibleDataLoss>
    <DropObjectsNotInSource>False</DropObjectsNotInSource>
    <IgnorePermissions>True</IgnorePermissions>
  </PropertyGroup>
</Project>
```

### TEST.publish.xml

```xml
<Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <TargetDatabaseName>EAO_DW_TEST</TargetDatabaseName>
    <TargetConnectionString>Data Source=$(db_server);Initial Catalog=$(dw_db_catalog);Integrated Security=True;TrustServerCertificate=True</TargetConnectionString>
    <DeployScriptFileName>EAO_DW_TEST.sql</DeployScriptFileName>
    <DeployReportFileName>EAO_DW_TEST.xml</DeployReportFileName>
    <BlockOnPossibleDataLoss>False</BlockOnPossibleDataLoss>
    <DropObjectsNotInSource>False</DropObjectsNotInSource>
    <IgnorePermissions>True</IgnorePermissions>
  </PropertyGroup>
</Project>
```

### UAT.publish.xml

```xml
<Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <TargetDatabaseName>EAO_DW_UAT</TargetDatabaseName>
    <TargetConnectionString>Data Source=$(db_server);Initial Catalog=$(dw_db_catalog);Integrated Security=True;TrustServerCertificate=True</TargetConnectionString>
    <DeployScriptFileName>EAO_DW_UAT.sql</DeployScriptFileName>
    <DeployReportFileName>EAO_DW_UAT.xml</DeployReportFileName>
    <BlockOnPossibleDataLoss>True</BlockOnPossibleDataLoss>
    <DropObjectsNotInSource>False</DropObjectsNotInSource>
    <IgnorePermissions>False</IgnorePermissions>
  </PropertyGroup>
</Project>
```

### PROD.publish.xml

```xml
<Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <TargetDatabaseName>EAO_DW_PROD</TargetDatabaseName>
    <TargetConnectionString>Data Source=$(db_server);Initial Catalog=$(dw_db_catalog);Integrated Security=True;TrustServerCertificate=True</TargetConnectionString>
    <DeployScriptFileName>EAO_DW_PROD.sql</DeployScriptFileName>
    <DeployReportFileName>EAO_DW_PROD.xml</DeployReportFileName>
    <BlockOnPossibleDataLoss>True</BlockOnPossibleDataLoss>
    <DropObjectsNotInSource>False</DropObjectsNotInSource>
    <IgnorePermissions>False</IgnorePermissions>
  </PropertyGroup>
</Project>
```

### SUPPORT.publish.xml

```xml
<Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <TargetDatabaseName>EAO_DW_SUPPORT</TargetDatabaseName>
    <TargetConnectionString>Data Source=$(db_server);Initial Catalog=$(dw_db_catalog);Integrated Security=True;TrustServerCertificate=True</TargetConnectionString>
    <DeployScriptFileName>EAO_DW_SUPPORT.sql</DeployScriptFileName>
    <DeployReportFileName>EAO_DW_SUPPORT.xml</DeployReportFileName>
    <BlockOnPossibleDataLoss>True</BlockOnPossibleDataLoss>
    <DropObjectsNotInSource>False</DropObjectsNotInSource>
    <IgnorePermissions>False</IgnorePermissions>
  </PropertyGroup>
</Project>
```

### SQLCMD values in publish profiles

Add this SQLCMD `ItemGroup` to each profile and let ADO substitute environment-specific values at deploy time.

```xml
<ItemGroup>
  <SqlCmdVariable Include="SourceServer">
    <Value>$(source_server)</Value>
  </SqlCmdVariable>
  <SqlCmdVariable Include="SourceDB">
    <Value>$(source_db)</Value>
  </SqlCmdVariable>
  <SqlCmdVariable Include="DWServer">
    <Value>$(db_server)</Value>
  </SqlCmdVariable>
  <SqlCmdVariable Include="DWDB">
    <Value>$(dw_db_catalog)</Value>
  </SqlCmdVariable>
  <SqlCmdVariable Include="SSASServer">
    <Value>$(sass_server)</Value>
  </SqlCmdVariable>
  <SqlCmdVariable Include="SSASCatalog">
    <Value>$(ssas_catalog)</Value>
  </SqlCmdVariable>
</ItemGroup>
```

## 9. Checklist - common SSDT project mistakes

| Severity | Mistake | Impact | Required correction |
|---|---|---|---|
| ?? Critical | Missing `master.dacpac` or `msdb.dacpac` references | Build errors for system objects and SQL Agent references | Add SSDT artifact references with correct SQL Server version. |
| ?? Critical | SQLCMD variables not defined in `.sqlproj` or publish profile | Deploy errors or unresolved token deployment | Define standard variables and map them in ADO variable groups. |
| ?? Critical | PostDeploy script not idempotent | Duplicate rows, failed reruns, or data loss on repeat deployment | Use `IF NOT EXISTS`, `MERGE`, or guarded inserts. |
| ?? Critical | Destructive changes hidden in PreDeploy or PostDeploy | Production data loss outside DACPAC review | Move to reviewed migration script with explicit approval. |
| ?? Warning | Object files in the wrong schema folder | Maintainability and review issue | Move files to canonical schema folder. |
| ?? Warning | SSAS partition source views placed in `Dimension\Views\` | Wrong schema and inconsistent SSAS source contract | Move all SSAS-facing views to `SSAS\Views\`. |
| ?? Warning | Table names repeat schema classification in the object name | Violates schema-as-classifier convention | Rename objects so the schema is the only classifier, for example `Dimension.Customer` or `Staging.Customer`. |
| ?? Warning | Staging tables missing `LineageKey INT NULL` | Load audit cannot trace source batches | Add `LineageKey` and populate from `Internal.Lineage`. |
| ?? Warning | Load procedure names do not use `Schema.Load{Entity}` | Inconsistent orchestration and review automation | Rename to `Staging.LoadCustomer`, `Dimension.LoadCustomer`, etc. |
| ?? Info | `Snapshots` or seed data marked as `Build` unintentionally | Unexpected DACPAC contents | Set non-object files to `None`. |

## Approved tooling

Use Visual Studio DB Projects (SSDT), Git, Tabular Editor 2.x, SSMS, Power BI Desktop (Report Server edition), DAX Studio, ALM Toolkit, BIML Express, and Azure DevOps Server. Do not introduce unsupported deployment tooling into project templates.

