<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# PBIRS Constraints & Best Practices

> **Target Stack:** Power BI Report Server (on-prem), SSAS Tabular (on-prem, CL 1200-1600), SQL Server 2016-2022, Active Directory / Windows Authentication, Kerberos. No Power BI Service. No Azure. No Microsoft Fabric.

**Deployed version:** Power BI Report Server May 2026 (v1.26.9637.31070, build 15.0.1121.109).  
Update cadence: typically 1 major quarterly release behind latest.

> **Maintenance note:** This feature comparison table is reviewed and updated at each plugin version bump, aligned with the PBIRS release cycle (~3x/year: Jan, May, Sep). If a feature is not in this table and the agent is uncertain, it must ask the user rather than assume availability. Agents also confirm the PBIRS version quarterly on long engagements.

---

## 1. PBIRS vs. Power BI Service - Feature Comparison

| Feature | Cloud (PBI Service) | PBIRS (On-Prem) | Notes |
|---|---|---|---|
| Live connection to SSAS Tabular | ✅ (via gateway) | ✅ (direct) | PBIRS preferred on-prem — no gateway overhead |
| Import mode (.pbix) | ✅ | ✅ | Limited by PBIRS server RAM |
| DirectQuery to SQL Server | ✅ | ✅ | |
| Composite models | ✅ | ❌ | Not supported in PBIRS |
| DAX User-Defined Functions (UDFs) | ✅ (GA, Sep 2025+) | ❌ | Requires CL 1702; not available on PBIRS |
| Visual Calculations | ✅ (GA) | ❌ | Cloud-only; no PBIRS support |
| Report-level DAX measures | ✅ | ❌ | Must exist in SSAS model |
| Calculated tables/columns (report) | ✅ | ❌ | Add to SSAS model |
| Field Parameters | ✅ | ⚠️ Version-dependent | Check PBIRS version; use Calculation Groups if unavailable |
| Power Query transforms in live connection | ❌ | ❌ | Neither supports this |
| Q&A / AI Insights / Dataflows | ✅ | ❌ | Not supported on-prem |
| RLS (model-defined) | ✅ | ✅ | Delegated via Kerberos |
| Report RLS (.pbix roles) | ✅ | ❌ | Not supported in live connection |
| Scheduled refresh | ✅ | ✅ (import only) | Live connection: no refresh needed |
| Subscriptions (email delivery) | ✅ | ✅ | PBIRS SSRS engine |
| Paginated reports (SSRS) | ✅ (Premium only) | ✅ (native) | Core PBIRS strength |
| Incremental refresh | ✅ (Premium) | ❌ | |
| Deployment pipelines | ✅ | ❌ | Manual deployment on-prem |
| Usage metrics | ✅ | ❌ | Not available in PBIRS |
| Custom visuals (AppSource) | ✅ | ⚠️ Certified only | Test each with PBIRS version |
| Azure AD / MFA | ✅ | ❌ | Windows/AD auth only |
| Themes (.json) | ✅ | ✅ | |
| Embed in SharePoint | ✅ | ✅ (iframe/web part) | |
| Mobile-optimised layouts | ✅ | ✅ | |
---

## 2. Version Compatibility Matrix

> **Critical:** A .pbix saved at a higher compatibility level than PBIRS supports will fail with a cryptic error.  
> **Always use "Power BI Desktop optimised for Power BI Report Server"** - separate download from standard Desktop.  
> Download: https://powerbi.microsoft.com/en-us/report-server/ ? "Advanced download options"

| PBIRS Release | Version | Max .pbix Compat Level |
|---|---|---|
| January 2021 | 15.0.1104.x | 1500 |
| October 2021 | 15.0.1106.x | 1510 |
| May 2022 | 15.0.1107.x | 1520 |
| October 2022 | 15.0.1108.x | 1530 |
| January 2023 | 15.0.1109.x | 1540 |
| May 2023 | 15.0.1110.x | 1550 |
| January 2024 | 15.0.1111.x | 1560 |
| May 2024 | 15.0.1112.x | 1567 |
| **May 2026** | **15.0.1121.109** | **1570+** |

### SSAS Tabular Compatibility

| SQL Server SSAS | CL | Min PBIRS |
|---|---|---|
| 2016 AS | 1200 | Any |
| 2017 AS | 1400 | Any |
| 2019 AS | 1500 | Jan 2021+ |
| 2022 AS | 1600 | May 2022+ (recommended: Jan 2023+) |

---

## 3. Live Connection - Hard Constraints

| Constraint | Workaround |
|---|---|
| No report-level DAX measures | Add measure to SSAS model; redeploy |
| No calculated tables/columns (report) | Add to SSAS model |
| No Power Query transforms | Transform in DW SQL view / partition query |
| No composite models | Move data to SSAS or use full import mode |
| No report RLS | All RLS must be SSAS model roles; Kerberos must delegate user |
| No field parameters (older PBIRS) | Check PBIRS version; upgrade or use Calculation Groups |
| No smart narrative / Anomaly Detection | Remove before publishing to PBIRS |
| No formatted .xlsx export from SSAS live | Use SSRS paginated report |
| Cannot change live connection target | Use DNS CNAME for SSAS server to enable seamless migration |

**Composite model error:** Opening a composite .pbix on PBIRS gives: *"This report requires a newer version of Power BI."*  
Fix: move import data into SSAS or use import mode entirely.

---

## 4. Report Design Best Practices

- Treat Power BI Desktop as a **visualisation tool only** - all business logic belongs in the SSAS model.
- New measure needed ? document spec ? SSAS developer adds to model ? redeploy ? report author refreshes field list ? republish. Maintain a **model change request log**.
- Date slicers: bind to Calendar hierarchy from SSAS; never create a local date table in the report.
- Hierarchies: drag SSAS-defined hierarchy onto rows/columns - do not re-build from individual columns.
- Slicer sync: use View ? Sync Slicers for shared Calendar and Region slicers across pages.
- Performance guard: use `IF(ISFILTERED(Calendar[CalendarYear]), 1, 0)` as visual-level filter on heavy visuals to prevent blank-page full scans.
- Cross-report drillthrough: supported in PBIRS - target report ? Pages ? Drillthrough ? "Cross-report" ON.
- Bookmarks: work as in Desktop - save filter/slicer/visibility state; stored inside .pbix.

---

## 5. Kerberos Authentication (KCD)

**Authentication flow:** User browser ? PBIRS (Windows Auth) ? PBIRS must impersonate user to SSAS (double-hop). Requires **Kerberos Constrained Delegation (KCD)**. NTLM cannot be forwarded.

### Configuration Steps

**Step 1: Register SPNs for PBIRS**
```cmd
setspn -S HTTP/pbirs-server.contoso.com CONTOSO\PBIRSServiceAccount
setspn -S HTTP/pbirs-server             CONTOSO\PBIRSServiceAccount
```

**Step 2: Register SPNs for SSAS**
```cmd
setspn -S MSOLAPSvc.3/ssas-server.contoso.com:2383 CONTOSO\SSASServiceAccount
setspn -S MSOLAPSvc.3/ssas-server.contoso.com       CONTOSO\SSASServiceAccount
setspn -S MSOLAPSvc.3/ssas-server                   CONTOSO\SSASServiceAccount
```

**Step 3: Configure Constrained Delegation** (AD Users and Computers)
1. PBIRS service account ? Properties ? Delegation tab
2. Select **"Trust this user for delegation to specified services only"** ? **"Use Kerberos only"**
3. Add SPN: `MSOLAPSvc.3/ssas-server.contoso.com`

```powershell
# PowerShell alternative (requires AD module)
Set-ADAccountControl -Identity "PBIRSServiceAccount" -TrustedForDelegation $false
Set-ADUser -Identity "PBIRSServiceAccount" `
    -Add @{ 'msDS-AllowedToDelegateTo' = "MSOLAPSvc.3/ssas-server.contoso.com" }
```

**Step 4: Verify IIS App Pool identity**
```powershell
Import-Module WebAdministration
Get-Item "IIS:\AppPools\PowerBIReportServer" | Select-Object processModel
# processModel.userName must be CONTOSO\PBIRSServiceAccount
```

**Step 5: Set PBIRS to Negotiate (Kerberos)** - edit `rsreportserver.config`:
```xml
<Authentication>
  <AuthenticationTypes><RSWindowsNegotiate /></AuthenticationTypes>
</Authentication>
```

**Step 6: Verify Kerberos ticket**
```powershell
klist purge
# Open PBIRS report that connects to SSAS, then:
klist tickets
# Must show: MSOLAPSvc.3/ssas-server.contoso.com
```

Verify delegation in SSAS log: `msmdsrv.log` must show `EffectiveUserName=CONTOSO\enduser`.

### Troubleshooting

| Symptom | Likely Cause | Resolution |
|---|---|---|
| Cannot connect to SSAS (all users) | SPN missing/wrong | Run `setspn -L` on both accounts; compare |
| Works for some users, not others | Some users on NTLM not Kerberos | Check domain membership; IE/Edge security zones |
| Access denied in SSAS log | User not in SSAS role | Add user/AD group to SSAS model role |
| RLS not applied (sees all data) | SSAS USERNAME() returns service account | Delegation not configured |
| Login failed in SSAS | Service account not in Read role | Grant SSAS role membership |

### PBIRS Service Account Minimum Permissions

| Resource | Permission |
|---|---|
| SSAS Model | SSAS Role with Read |
| ReportServer DB | db_owner on ReportServer and ReportServerTempDB |
| Network share (subscriptions) | Read/Write on delivery share |
| Windows local server | Logon as service |

### Org Standard: PBIRS Folder Permissions (AD Groups)

PBIRS folder permissions use **Active Directory groups exclusively** — individual accounts are never granted folder access directly. The PBIRS folder hierarchy mirrors the project/department structure.

**Standard two-role folder permission pattern (every BI project):**

| PBIRS Role | AD Group pattern | Capability |
|---|---|---|
| `Browser` | `DL-BI-{ProjectName}-Read` | View and run reports in the folder |
| `Publisher` | `DL-BI-{ProjectName}-Readwrite` | Upload, overwrite, and manage reports in the folder |

- The `Content Manager` role (full folder admin) is reserved for the BI team service account and BI admins only — not granted to project-level groups
- Folder structure in PBIRS must mirror the Git repository structure (e.g. `/Reports/{ProjectName}/`)
- Access to the SSAS model (SSAS role membership) and access to the PBIRS folder (PBIRS role) are managed **independently** — a user needs both to view a live-connection report
- The PBIRS service account (`svc-pbirs`) must have `Browser` access or a dedicated service role on every folder it deploys to

**Example PowerShell — set folder Browser permission for an AD group:**
```powershell
$base = "http://pbirs-server/ReportServer/api/v2.0"
$group = "CONTOSO\DL-BI-SalesProject-Read"
$folderPath = "/Reports/SalesProject"

$policy = @{
    GroupUserName = $group
    Roles = @(@{ Name = "Browser" })
} | ConvertTo-Json -Depth 3

Invoke-RestMethod "$base/Folders(Path='$([Uri]::EscapeDataString($folderPath))')/Policies" `
    -Method PUT -Body $policy -ContentType "application/json" -UseDefaultCredentials
```

---

## 6. Paginated Reports vs. Canvas Reports

| Requirement | Canvas Report | Paginated (SSRS) |
|---|---|---|
| Interactive exploration, drill-down, cross-filter | ? | ? |
| Fixed-format output / print / PDF | ?? Limited | ? |
| Pixel-perfect layout (invoices, certificates) | ? | ? |
| Multi-page / data-driven subscriptions | ? | ? |
| Table/list with thousands of rows | ? | ? |
| Scheduled email with formatted attachment | ?? PNG/PDF only | ? Excel/PDF/Word/CSV |
| Historical trend / KPIs / dashboards | ? | ?? Limited |

- **DAX dataset:** `EVALUATE SUMMARIZECOLUMNS(...)` against SSAS Tabular - use for all reports. This is the only dataset type used in this organisation (SSAS Tabular + DAX only; no MDX/Multidimensional).

**Drillthrough from canvas ? paginated report:**
```
URL Action = CONCATENATE(
  "http://pbirs-server/ReportServer/Pages/ReportViewer.aspx?",
  "%2fReports%2fSales%2fSalesDetailPaginated&rs:Command=Render",
  "&StartYear=", SELECTEDVALUE(Calendar[CalendarYear]),
  "&RegionKey=",  SELECTEDVALUE(Region[RegionKey])
)
```

---

## 7. Deployment and Versioning

### REST API - Upload/Overwrite .pbix

```powershell
function Publish-PBIRSReport {
    param(
        [string] $PbixPath,
        [string] $TargetFolder,   # e.g. "/Reports/Sales"
        [string] $ReportName,     # e.g. "SalesSummary"
        [string] $PBIRSBase = "http://pbirs-server/ReportServer/api/v2.0"
    )
    $fileBytes = [System.IO.File]::ReadAllBytes($PbixPath)
    $boundary  = [System.Guid]::NewGuid().ToString()
    $fileName  = Split-Path $PbixPath -Leaf
    $header    = "--$boundary`r`nContent-Disposition: form-data; name=`"File`"; filename=`"$fileName`"`r`nContent-Type: application/octet-stream`r`n`r`n"
    $payload   = [System.Text.Encoding]::UTF8.GetBytes($header) + $fileBytes +
                 [System.Text.Encoding]::UTF8.GetBytes("`r`n--$boundary--`r`n")
    $url = "$PBIRSBase/PowerBIReports?path=$([Uri]::EscapeDataString("$TargetFolder/$ReportName"))"
    Invoke-WebRequest -Uri $url -Method POST -Body $payload `
        -Headers @{ "Content-Type" = "multipart/form-data; boundary=$boundary" } `
        -UseDefaultCredentials
}

# Usage:
Publish-PBIRSReport -PbixPath "$(report_root)\SalesSummary.pbix" `
    -TargetFolder "/Reports/Sales" -ReportName "SalesSummary"
```

### ReportingServicesTools Module

```powershell
Install-Module -Name ReportingServicesTools -Scope CurrentUser
Write-RsRestReport `
    -Path            "$(report_root)\SalesSummary.pbix" `
    -RsFolder        "/Reports/Sales" `
    -ReportServerUri "http://pbirs-server/ReportServer"
```

### List Reports / Create Shared Data Source

```powershell
$base = "http://pbirs-server/ReportServer/api/v2.0"

# List all Power BI reports
(Invoke-RestMethod "$base/PowerBIReports?`$expand=Properties" -UseDefaultCredentials).value |
    Select-Object Name, Path, ModifiedDate | Format-Table -AutoSize

# Create shared SSAS data source
$ds = @{
    Name = "SSAS_SalesModel"
    ConnectionString = "Data Source=ssas-server;Initial Catalog=SalesTabularModel"
    DataSourceType = "OLEDB-MD"
    CredentialRetrieval = "Integrated"
} | ConvertTo-Json
Invoke-RestMethod "$base/DataSources" -Method POST -Body $ds `
    -ContentType "application/json" -UseDefaultCredentials
```

### Version Control
- PBIRS has **no built-in version history** for .pbix files.
- Store .pbix in Git; folder structure mirrors PBIRS folder structure.
- Tag commits with PBIRS server + target folder on each deployment.

---

## 8. Performance Tuning

| Root Cause | Diagnostic | Fix |
|---|---|---|
| Too many visuals per page | F12 Network - many parallel SSAS queries | Reduce visuals; bookmarks to hide off-screen visuals |
| Heavy measures without aggregations | DAX Studio Server Timings - high FE time | Add user-defined aggregations; optimise DAX |
| "Show All" slicers force full scans | SSAS query log - full dimension scans | Use dropdown slicer; reduce member count |
| Large model not fitting in SSAS memory | SSAS memory counters (Perfmon/Process Explorer) | Increase max memory; remove unused columns |
| Subscription concurrency hitting SSAS | Multiple subscribers simultaneously | Stagger schedules; increase SSAS thread pool (DBA — raise as 🔵 LOW suggestion only) |

**Connection note:** Each Kerberos-delegated user has its own SSAS connection (no cross-user pooling). Monitor: `SELECT * FROM $SYSTEM.DISCOVER_CONNECTIONS`.

**SSAS memory** (`msmdsrv.ini`):
```xml
<HardMemoryLimit>80</HardMemoryLimit>       <!-- % of server RAM -->
<VertiPaqMemoryLimit>60</VertiPaqMemoryLimit>
<LowMemoryLimit>40</LowMemoryLimit>
<QueryMemoryLimit>10</QueryMemoryLimit>     <!-- GB per query -->
```

**Execution snapshots** (for reports with acceptable data lag):
PBIRS web portal ? Report ? Manage ? Processing Options ? "Render from execution snapshot" ? schedule after SSAS processing completes.

**Capacity planning:**

| Component | Minimum | Recommended |
|---|---|---|
| PBIRS RAM | 8 GB | 16-32 GB |
| PBIRS CPU | 4 cores | 8-16 cores |
| SSAS RAM | 16 GB | 32-128 GB |
| SSAS CPU | 8 cores | 16+ cores |
| Network PBIRS?SSAS | 1 Gbps | 10 Gbps |