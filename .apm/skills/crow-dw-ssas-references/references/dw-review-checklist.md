<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

Data Warehouse Review Checklist — On-Premises SQL Server / SSAS Tabular

> **Stack:** SQL Server 2016–2022 DW (on-prem), SSAS Tabular (CL 1200–1600), PBIRS, SSIS, SQL Agent, Active Directory.
> No Azure / Power BI Service / Fabric.

---

## Severity Levels

| Level | Label | Meaning |
|---|---|---|
| 🔴 | **CRITICAL** | Data integrity risk, security vulnerability, or outage risk. Block deployment. |
| 🟡 | **WARNING** | Performance risk, maintainability issue, or best practice deviation. Fix before next release. |
| 🟢 | **INFO** | Observation or future improvement recommendation. |

---

## Section 1: SQL Server Data Warehouse — Physical Layer

### 1.1 Fact Table Audit

| Check | Sev | Notes |
|---|---|---|
| All fact tables have a surrogate integer PK | 🟡 | |
| FK to all dimensions defined (trusted constraints at minimum) | 🟡 | |
| Date dimension FK is NOT NULL | 🔴 | Use sentinel `'1753-01-01'` instead of NULL — ELT must ISNULL on LEFT JOIN Calendar |
| No varchar/nvarchar measure columns (must be numeric) | 🔴 | Implicit conversion overhead in SSAS |
| Fact table grain documented | 🔴 | Undefined grain leads to incorrect aggregations |
| Late-arriving facts handling documented | 🟡 | |

```sql
SELECT s.name AS SchemaName, t.name AS TableName, SUM(p.rows) AS EstRows
FROM sys.indexes i JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
JOIN sys.tables t ON i.object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE t.is_ms_shipped = 0 AND i.index_id IN (0,1) AND s.name = 'Fact'
GROUP BY s.name, t.name ORDER BY EstRows DESC;
```

---

### 1.2 Dimension Table Audit

| Check | Sev | Notes |
|---|---|---|
| All dimensions have surrogate integer PK | 🔴 | Natural keys cause SSAS relationship overhead |
| Unknown/default member row exists (`{EntityName}Key = -1`; DATE dims use `'1753-01-01'`) | 🟡 | Single sentinel per SQLBI simplification — no -2/-3 variants |
| SCD Type 2 dims have IsCurrent, EffectiveFrom, EffectiveTo | 🟡 | |
| Conformed dimensions shared across fact tables (bus matrix) | 🔴 | Siloed dims prevent cross-subject-area analysis |
| Dimension attributes have human-readable labels | 🟡 | |
| [Dimension].[Calendar] covers min(fact date) − 5yr to today + 3yr (excluding sentinels) | 🔴 | Gaps break time intelligence; run contiguity check from `dw-calendar-build.md §5` |
| [Dimension].[Calendar] marked as Date Table in SSAS; `[Date Key]` selected as date column | 🔴 | Required for DATESYTD, SAMEPERIODLASTYEAR, etc. |
| [Dimension].[Calendar].[Date Key] is DATE type (not INT YYYYMMDD); [YYYYMMDD] INT available as separate column | 🔴 | |
| [Dimension].[Calendar] sentinel rows `'1753-01-01'` / `'9999-12-31'` exist in SQL table; SSAS.v_Calendar filters them out | 🔴 | SQL FK integrity + SSAS contiguity both required |
| [Dimension].[Calendar] FiscalYear/Quarter/Month populated if non-calendar FY used | 🟡 | |
| Large dimensions (>1M rows) reviewed for SSAS memory impact | 🟡 | |

```sql
-- Dimension tables missing IsCurrent/IsActive/IsUnknown column
SELECT s.name AS SchemaName, t.name AS TableName, SUM(p.rows) AS RowCount
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0,1)
WHERE s.name = 'Dimension' AND t.is_ms_shipped = 0 AND t.name <> 'Calendar'
  AND NOT EXISTS (SELECT 1 FROM sys.columns c WHERE c.object_id = t.object_id
    AND c.name IN ('IsCurrent','IsActive','IsUnknown'))
GROUP BY s.name, t.name ORDER BY t.name;
```

---

### 1.3 Schema Health

| Check | Sev | Notes |
|---|---|---|
| All DW objects in dedicated schemas (`Dimension`, `Fact`, `Staging`, `Internal`) — not `dbo` | 🟡 | |
| Staging tables in `Staging` schema (not mixed with presentation layer) | 🟡 | |
| Control/audit tables in `Internal` schema (`Lineage`, `IncrementalLoads`, `LastUpdatedSource`, `ProcedureError`, `DbVersion`) | 🟡 | |
| SSAS views in `SSAS` schema (views only — no tables) | 🟡 | |
| No `SELECT *` in views or procs feeding SSAS partitions | 🟡 | Column additions silently break partitions |
| Views used as SSAS partition sources (not direct table access) | 🟡 | |

---

### 1.4 SQL Server Physical DW Performance

| Check | Sev | Notes |
|---|---|---|
| Large fact tables (>10M rows) have a columnstore index | 🔴 | 10–100× compression and scan speed for analytics |
| CCI on pure DW tables; NCCI on OLTP-adjacent | 🟡 | |
| Partition scheme aligns with ETL load pattern (monthly/daily) | 🟡 | |
| Statistics up to date on all DW tables | 🔴 | Stale statistics cause query plan regressions |
| AUTO_UPDATE_STATISTICS ON for the DW database | 🟡 | |
| Missing index DMV recommendations reviewed | 🟡 | |
| No table scans on dim tables >100K rows in SSAS partition queries | 🟡 | |
| Query Store enabled (SQL Server 2016+) | 🟢 | |

```sql
-- Top 20 missing index recommendations
SELECT TOP 20
    ROUND(migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans), 0) AS EstImprovement,
    mid.statement AS TableName, mid.equality_columns, mid.inequality_columns, mid.included_columns
FROM sys.dm_db_missing_index_groups mig
JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
JOIN sys.dm_db_missing_index_details  mid  ON mig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID() ORDER BY EstImprovement DESC;

-- Columnstore on Fact tables
SELECT s.name AS SchemaName, t.name, i.type_desc, SUM(p.rows) AS Rows
FROM sys.tables t JOIN sys.indexes i ON t.object_id = i.object_id
JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'Fact' AND t.is_ms_shipped = 0
  AND i.type_desc IN ('CLUSTERED COLUMNSTORE','NONCLUSTERED COLUMNSTORE')
GROUP BY s.name, t.name, i.type_desc ORDER BY Rows DESC;

-- Fact tables WITHOUT columnstore:
SELECT s.name AS SchemaName, t.name
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'Fact' AND t.is_ms_shipped = 0
  AND NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id = t.object_id
    AND i.type_desc IN ('CLUSTERED COLUMNSTORE','NONCLUSTERED COLUMNSTORE'));
```

---

### 1.5 ETL Process Audit

| Check | Sev | Notes |
|---|---|---|
| SSIS package inventory documented (name, source, target, schedule, owner) | 🔴 | Undocumented packages = maintenance and DR risk |
| Incremental load strategy defined (`Internal.IncrementalLoads` / CDC / full reload) | 🔴 | Full reloads of large tables unacceptable in production |
| `Internal.Lineage` populated for every package run | 🔴 | Required for monitoring, SLA, and troubleshooting |
| Error redirect paths on all Data Flow tasks (no silent discards) | 🔴 | Silent drops = undetected data loss |
| Error rows written to dedicated error table (source, code, description) | 🟡 | |
| SSIS packages use project-level connection managers | 🟡 | |
| SSIS packages deployed to SSISDB (not file system) | 🟡 | |
| Environment variables for connection strings (not hard-coded) | 🔴 | Hard-coded strings = security and maintainability risk |
| Checkpoints enabled on long-running packages | 🟡 | |
| Load procedures are idempotent | 🔴 | Non-idempotent loads cause data corruption on re-run |
| Package logging level `Basic` or higher | 🟡 | `None` makes troubleshooting impossible |
| Row counts logged per run (inserted / updated / rejected) | 🟡 | |

```sql
-- SSIS Catalog package inventory
SELECT f.name AS Folder, prj.name AS Project, pkg.name AS Package, prj.last_deployed_time
FROM SSISDB.catalog.packages pkg
JOIN SSISDB.catalog.projects prj ON pkg.project_id = prj.project_id
JOIN SSISDB.catalog.folders  f   ON prj.folder_id = f.folder_id
ORDER BY f.name, prj.name, pkg.name;

-- SSIS OnError events (recent failures)
SELECT TOP 100 m.execution_id, m.message_time, m.package_name, m.task_name, m.message
FROM SSISDB.catalog.event_messages m WHERE m.event_name = 'OnError' ORDER BY m.message_time DESC;
```

---

### 1.6 SQL Server Agent Job Audit

| Check | Sev | Notes |
|---|---|---|
| DW load and SSAS processing jobs inventoried and documented | 🔴 | Undocumented jobs = DR risk |
| DW load completes before SSAS processing begins | 🔴 | Processing before load = stale/partial model |
| SSAS processing job has failure alerting (email to operator) | 🔴 | Silent failures = stale reports with no warning |
| DW load job has failure alerting | 🔴 | |
| Job schedules documented with SLA (e.g., "DW load by 06:00") | 🟡 | |
| Jobs use Windows proxy accounts — not SA or sysadmin | 🔴 | Least-privilege requirement |
| Job step failure action defined (not default "quit with success") | 🟡 | |
| Max concurrent SSAS processing jobs = 1 | 🟡 | |

```sql
-- Job schedule and last run status
SELECT j.name AS Job,
    CASE j.last_run_outcome WHEN 0 THEN 'Failed' WHEN 1 THEN 'Succeeded' ELSE 'Unknown' END AS Outcome,
    msdb.dbo.agent_datetime(j.last_run_date, j.last_run_time) AS LastRun, s.name AS Schedule
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.sysjobschedules js ON j.job_id = js.job_id
LEFT JOIN msdb.dbo.sysschedules s ON js.schedule_id = s.schedule_id
WHERE j.enabled = 1 ORDER BY j.name;

-- Failed jobs last 7 days
SELECT j.name, jh.run_date, jh.run_time, jh.message
FROM msdb.dbo.sysjobhistory jh JOIN msdb.dbo.sysjobs j ON jh.job_id = j.job_id
WHERE jh.run_status = 0
  AND msdb.dbo.agent_datetime(jh.run_date, jh.run_time) >= DATEADD(DAY, -7, GETDATE())
ORDER BY msdb.dbo.agent_datetime(jh.run_date, jh.run_time) DESC;

-- Jobs with no failure notification
SELECT j.name AS Job, op.name AS Operator FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.sysoperators op ON j.notify_email_operator_id = op.id
WHERE j.enabled = 1 AND (j.notify_level_email = 0 OR j.notify_email_operator_id IS NULL);
```

---

## Section 2: SSAS Tabular Model Audit

### 2.1 Model Metadata

| Check | Sev | Notes |
|---|---|---|
| Compatibility level documented (1200+ SQL 2016, 1500+ SQL 2019, 1600 SQL 2022) | 🔴 | |
| Model name, version, owner documented | 🟡 | |
| Partition queries do not use `SELECT *` | 🔴 | Column additions break model silently |
| Model does not import unnecessary columns | 🟡 | Each column consumes VertiPaq memory |

---

### 2.2 Relationship Audit

| Check | Sev | Notes |
|---|---|---|
| All active relationships use integer key columns | 🟡 | |
| No bidirectional cross-filter unless explicitly required and documented | 🟡 | Can cause ambiguous filter paths |
| All inactive relationships documented with reason | 🟢 | |
| No circular relationship chains | 🔴 | SSAS will refuse to deploy |
| No fact-to-fact relationships — use bridge tables | 🔴 | Direct fact-to-fact causes double-counting |

---

### 2.3 Measure Audit

| Check | Sev | Notes |
|---|---|---|
| All measures use `DIVIDE()` not `/` | 🔴 | Division by zero errors in reports |
| All measures have Format String set (not "Auto") | 🟡 | |
| All measures have Description populated | -- | |
| All measures organised in Display Folders | 🟡 | |
| No measure uses implicit aggregation only | 🟡 | |
| Time intelligence measures tested at multiple date grains | 🔴 | |

---

### 2.4 RLS Audit

| Check | Sev | Notes |
|---|---|---|
| At least one SSAS role defined (not relying on admin access only) | 🔴 | Without roles all users see all data |
| Dynamic RLS uses `USERNAME()` — not `USERPRINCIPALNAME()` | 🔴 | UPN unreliable on on-prem SSAS |
| RLS tested with impersonation for representative users | 🔴 | |
| No "admin backdoor" role with no row filter visible to non-admins | 🔴 | |
| AD group membership used for role assignment | 🟡 | Individual usernames require model redeployment |
| Column-level security for sensitive columns reviewed per role | 🟡 | |

```powershell
# Enumerate SSAS roles and members (AMO)
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices") | Out-Null
$svr = New-Object Microsoft.AnalysisServices.Server
$svr.Connect("Data Source=SSAS_SERVER_NAME")
$db = $svr.Databases["ModelName"]
$db.Roles | ForEach-Object {
    $roleName = $_.Name
    $_.Members | ForEach-Object {
        [PSCustomObject]@{ Role = $roleName; Member = $_.Name; Type = $_.MemberType }
    }
} | Format-Table -AutoSize
$svr.Disconnect()
```

---

### 2.5 Model Memory and Performance

| Check | Sev | Notes |
|---|---|---|
| Total model memory within 70% of SSAS max server memory | 🔴 | Exceeding causes processing failures or query errors |
| SSAS max server memory configured (not default unlimited) | 🔴 | Unlimited starves OS and SQL Server on shared server |
| Largest table memory identified via DMV | 🟡 | |
| Unused calculated columns removed | 🟡 | |

```dax
-- DAX Studio (DMV mode): VertiPaq memory by column
SELECT MEASURE_GROUP_NAME AS TableName, ATTRIBUTE_NAME AS ColumnName,
    DICTIONARY_SIZE AS DictBytes, USED_SIZE AS UsedBytes, ROWS_COUNT
FROM $SYSTEM.DISCOVER_STORAGE_TABLE_COLUMN_SEGMENTS ORDER BY USED_SIZE DESC
```

---

### 2.6 SSAS Processing Audit

| Check | Sev | Notes |
|---|---|---|
| Processing mode documented per object (Full / ProcessAdd / Defrag) | 🔴 | Wrong mode triggers full reprocess, blocking reports |
| Dimension processing always precedes fact processing | 🔴 | Facts before dims = orphan key errors |
| Processing time SLA defined and measured | 🟡 | |
| Partition-level incremental processing for large tables (>50M rows) | 🟡 | |
| `ProcessAdd`/`ProcessUpdate` for fact partitions where possible | 🟡 | `ProcessFull` only after schema changes |
| Processing includes a `Recalc` step after partition loads | 🔴 | Without Recalc, indexes and calc cols are stale |
| Processing failure leaves model in last successful state | 🔴 | Partial processing corrupts model metadata |
| SSAS processing does not run during business hours | 🟡 | |
| Processing logged (start/end, objects processed, success/failure) | 🟡 | |

```dax
-- DAX Studio (DMV mode): last processing per partition
SELECT DATABASE_NAME, CUBE_NAME AS Model, MEASURE_GROUP_NAME AS TableName,
    PARTITION_NAME, LAST_DATA_UPDATE AS LastProcessed, STATE AS PartitionState
FROM $SYSTEM.DISCOVER_PARTITION_STAT ORDER BY LAST_DATA_UPDATE DESC
```

```powershell
# SSAS partition processing state (AMO)
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices") | Out-Null
$svr = New-Object Microsoft.AnalysisServices.Server
$svr.Connect("Data Source=SSAS_SERVER_NAME")
foreach ($t in $svr.Databases["ModelName"].Model.Tables) {
    foreach ($p in $t.Partitions) {
        Write-Host "$($t.Name) | $($p.Name) | $($p.State) | $($p.ModifiedTime)"
    }
}
$svr.Disconnect()
```

---

### 2.7 PBIRS Live Connection Audit

| Check | Sev | Notes |
|---|---|---|
| PBIRS version documented; compatibility with SSAS verified | 🔴 | Version mismatch causes connection failures |
| .pbix files use a compat level supported by the PBIRS version | 🔴 | Newer .pbix CL fails to open on older PBIRS |
| No report-level DAX measures in live connection .pbix | 🔴 | Not supported in live connection mode |
| No calculated tables/columns via Power Query on live connection | 🔴 | Not supported; causes open errors |
| No composite model features in live connection reports | 🔴 | DirectQuery + import mix not supported |
| PBIRS service account has Read permission on SSAS model role | 🔴 | Must be member of at least one SSAS role |
| Kerberos delegation configured if PBIRS and SSAS on different servers | 🔴 | Double-hop fails without KCD |
| .pbix files in version control | 🟡 | |
| RLS tested end-to-end: user → PBIRS → SSAS role via Kerberos | 🔴 | RLS only works with successful identity delegation |

| PBIRS Release | Max .pbix CL | Supported SSAS |
|---|---|---|
| Jan 2020 | 1460 | SSAS 2012–2019 |
| May 2021 | 1500 | SSAS 2012–2019 |
| May 2022 | 1520 | SSAS 2012–2022 |
| Jan 2023 | 1540 | SSAS 2012–2022 |
| May 2024 | 1567 | SSAS 2016–2022 |

```powershell
$resp = Invoke-WebRequest "http://PBIRS_SERVER/ReportServer/api/v2.0/System" -UseDefaultCredentials
($resp.Content | ConvertFrom-Json).ProductVersion
```

---

### 2.8 DAX Measure Pattern Review

| Check | Sev | Notes |
|---|---|---|
| No `FILTER(AllTable, [Measure] > x)` patterns | 🟡 | FE overhead; replace with column filter |
| All time intelligence measures use the marked Date Table | 🔴 | |
| Date range boundary convention documented and consistent: inclusive-inclusive user contract; half-open `>= start AND < end+1` in ELT SQL | 🟠 | Undocumented convention causes silent last-day data loss when switching between implementations |
| No `BETWEEN` on DATETIME source columns in ELT SPs | 🟠 | Use `>= start AND < next_period_start` — `BETWEEN` drops 23:59:59 on the upper bound |
| `USERELATIONSHIP` used correctly for role-playing dimensions | 🟡 | |
| Calculation Groups (if present) have Precedence set and documented | 🟡 | |
| Dynamic RLS measures tested under impersonation | 🔴 | |
| No `FORMAT()` inside measure body | 🟡 | Use Format String property instead |
| `DIVIDE()` used exclusively — no `/` operator | 🔴 | |

---

## Section 3: Security Review

### 3.1 Active Directory Group Assignments

| Check | Sev | Notes |
|---|---|---|
| SSAS roles assigned AD groups — not individual user accounts | 🟡 | |
| AD group names documented and linked to business function | 🟡 | e.g., `DW_SSAS_FinanceReadOnly` → Finance read |
| Each role has minimum permissions (Read/ReadDefinition for report users) | 🔴 | No report user should have Administrator or Process |
| No "Everyone" or "Domain Users" in unrestricted SSAS roles | 🔴 | Grants all domain users full model access |
| SSAS administrators role restricted to named IT staff | 🔴 | SSAS Administrator bypasses all RLS |

> Use PowerShell AMO script from Section 2.4 to enumerate role members.

---

### 3.2 Kerberos Delegation (Double-Hop)

User → PBIRS (hop 1) → SSAS (hop 2). Without KCD, hop 2 fails silently.

| Check | Sev | Notes |
|---|---|---|
| SPN registered for PBIRS service account (`HTTP/pbirs-server.domain.com`) | 🔴 | |
| SPN registered for SSAS service account (`MSOLAPSvc.3/ssas-server.domain.com`) | 🔴 | |
| KCD: PBIRS account allowed to delegate to SSAS SPN | 🔴 | AD → PBIRS account → Delegation tab |
| Delegation type is Constrained (not unconstrained) | 🔴 | Unconstrained delegation = security risk |
| Kerberos verified: SSAS log shows `EffectiveUserName` | 🟡 | |

```powershell
setspn -L DOMAIN\PBIRSServiceAccount
setspn -L DOMAIN\SSASServiceAccount
# Expected SSAS SPNs: MSOLAPSvc.3/ssas-server.domain.com:2383  MSOLAPSvc.3/ssas-server
```

---

### 3.3 PBIRS Service Account Permissions

| Check | Sev | Notes |
|---|---|---|
| PBIRS service account is a dedicated service account (not personal) | 🔴 | Personal accounts expire passwords |
| Has Read permission on SSAS model role | 🔴 | Required for service-level report rendering |
| Does NOT have SSAS Administrator or Process permissions | 🔴 | |
| Is not a local administrator on the SSAS server | 🔴 | |
| "Password never expires" with strong password or gMSA | 🟡 | |

---

### 3.4 Column-Level Security and Data Classification

| Check | Sev | Notes |
|---|---|---|
| PII columns identified and documented | 🔴 | Data Protection compliance requirement |
| Sensitive columns (salary, PII, financial) hidden per SSAS role | -- | Set Hidden = True per role in `TabularEditor.exe` |
| SQL Server sensitivity labels applied (`ADD SENSITIVITY CLASSIFICATION`) | 🟡 | Audit coverage via `sys.sensitivity_classifications` |
| SSAS model does not import columns not required for any report | 🟡 | |

---

### 3.5 Audit Logging and Data Freshness

| Check | Sev | Notes |
|---|---|---|
| SQL Server Audit on DW database (DDL + DML on sensitive tables) | 🟡 | |

| ETL audit table retains load history ≥ 90 days | 🟡 | |
| Data freshness timestamp visible in reports (last DW load, last SSAS process) | 🟡 | |
| Stale-data alerting: if load fails, reports show last-good-data watermark | 🟡 | |

---

## Section 4: Review Output Template

```markdown
## DW / SSAS Review — [Project Name] — [Date]

**Reviewer:** [Name]
**Review Scope:** [Full model / New feature / Post-incident]
**Environment:** [Server names, SSAS version, PBIRS version, SQL Server version]

---

### Critical Findings (🔴)

| # | Finding | Location | Recommendation | Owner | Due Date |
|---|---|---|---|---|---|
| C1 | | | | | |

### Warning Findings (🟡)

| # | Finding | Location | Recommendation | Owner | Due Date |
|---|---|---|---|---|---|
| W1 | | | | | |

### Info / Observations (🟢)

| # | Observation | Notes |
|---|---|---|
| I1 | | |

---

### Summary Scorecard

| Section | Critical | Warning | Info | Status |
|---|---|---|---|---|
| 1.1 Fact Table Audit | | | | ✅ / ⚠️ / ❌ |
| 1.2 Dimension Audit | | | | |
| 1.3 Schema Health | | | | |
| 1.4 Physical Performance | | | | |
| 1.5 ETL Process | | | | |
| 1.6 SQL Agent Jobs | | | | |
| 2.x SSAS Model | | | | |
| 2.6 SSAS Processing | | | | |
| 2.7 PBIRS Live Connection | | | | |
| 3.x Security | | | | |

**Overall Recommendation:** [ APPROVE | APPROVE WITH CONDITIONS | REJECT ]
```
