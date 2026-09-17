<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# Security Implementation Reference

**Status:** Partially implemented — knowledge gap exists on PBIRS→SSAS connection authentication.  
See Section 1 before implementing RLS.

## 1. Connection Chain Overview

The effective query path is three-tier:

**User browser → PBIRS → SSAS Tabular → SQL Server DW**

```text
+--------------+      +--------+      +---------------+      +----------------+
| User Browser | ---> | PBIRS  | ---> | SSAS Tabular  | ---> | SQL Server DW  |
+--------------+      +--------+      +---------------+      +----------------+
       AD auth           report auth       model auth            data access
```

> **⚠️ Knowledge gap:** The exact authentication method between PBIRS and SSAS is currently undocumented. Before implementing RLS, the following must be confirmed:
> - Is the SSAS data source in PBIRS using Windows authentication (PBIRS service account) or stored SQL/Windows credentials?
> - Does the PBIRS service account have an SSAS server role (admin) or is it an SSAS database role member?
> - Is Kerberos constrained delegation configured between PBIRS and SSAS? (required for EffectiveUserName to work)
> - What is the SQL login "dw"? Is it a SQL Server login or a Windows service account?

## 2. SQL Server Database Permissions

Recommended least-privilege pattern for the DW database:

- **SSAS service account:** grant read-only access to the DW objects consumed by the model, usually `SSAS.v_*` views. Prefer schema-level `SELECT` grants on `SSAS` over broad membership in `db_datareader`. Do **not** grant direct table access unless the model genuinely needs it.
- **PBIRS service account:** if paginated reports query the DW directly, grant read access only on the required schemas.
- **ELT service account:** grant `db_datawriter` plus `EXECUTE` on stored procedures in `ELT` and `Staging`; do not grant direct access to `Dimension`, `Fact`, or `Snapshots` beyond what those procedures expose.
- **DBA / admin accounts:** `sysadmin` is operationally separate and not part of the least-privilege design.
- **Convention:** use schema-level grants, never object-level grants.

```sql
-- Grant SSAS service account read access to DW views
-- Replace [DOMAIN\ssas-service] with the actual service account
CREATE USER [DOMAIN\ssas-service] FOR LOGIN [DOMAIN\ssas-service];
GRANT SELECT ON SCHEMA::[SSAS] TO [DOMAIN\ssas-service];
GRANT SELECT ON SCHEMA::[Dimension] TO [DOMAIN\ssas-service];   -- if direct table access needed
```

## 3. SSAS Tabular Role Management

### 3.1 Role Basics

An SSAS Tabular role combines:

- A model permission such as `read`
- Optional DAX row filters
- Assigned Windows users and/or AD groups

Key points:

- Roles live in the BIM/JSON model, are managed in Tabular Editor, and are committed to git.
- A user can belong to multiple roles; row filters are OR'd, so the most permissive access wins.
- The default **Everyone (no-role)** state is **no access**; users must be explicitly assigned to a database role.
- The SSAS server-level **Administrators** role is separate from database roles.

### 3.2 Tabular Editor Role JSON Pattern

```json
{
  "name": "Role_RegionEast",
  "modelPermission": "read",
  "members": [
    { "memberName": "DOMAIN\\DL-ReportViewers-RegionEast", "memberType": "Windows" }
  ],
  "tablePermissions": [
    {
      "name": "Fact Sales Transaction",
      "filterExpression": "'Fact Sales Transaction'[Region Code] = \"EAST\""
    }
  ]
}
```

### 3.3 Fixed Roles (Practical with Current Setup)

If PBIRS connects to SSAS as a fixed service account such as `dw`, SSAS cannot distinguish the actual report viewer. In that case, **fixed roles** are the practical near-term pattern.

- Create one SSAS role per slice, such as `Role_RegionEast`, `Role_RegionWest`, `Role_AllRegions`.
- Assign AD groups to each SSAS role.
- In PBIRS, point the dataset or shared data source at the required SSAS role by using the `Roles` connection string property.

```text
Data Source=ssas-server; Initial Catalog=WAO_Model; Roles=Role_RegionEast
```

Limitations:

- Each new slice requires a new SSAS role.
- Each new slice usually requires a matching AD group.
- PBIRS data sources or reports must be updated when the role mapping changes.

### 3.4 Dynamic RLS (Requires Architecture Change)

Dynamic RLS uses `USERNAME()` in DAX filters to resolve the current user against a permissions table in the model. **Always use `USERNAME()`** (returns `DOMAIN\username`) on-premises — `USERPRINCIPALNAME()` is designed for Azure AS and is unreliable with on-premises SSAS + Kerberos delegation.

**Prerequisite:** SSAS must receive the end-user identity, not only the PBIRS service account identity.

| Option | What It Requires |
|---|---|
| **EffectiveUserName** | PBIRS passes `EffectiveUserName=user@domain` in the SSAS connection string. Requires the PBIRS service account to have SSAS admin rights or SSAS impersonation privilege. Requires Kerberos delegation if PBIRS and SSAS are on different servers. |
| **CustomData** | PBIRS passes an identifier in the `CustomData=` connection string property. DAX uses `CUSTOMDATA()` to resolve permissions. Less standard; requires strict sanitisation and governance. |

> **⚠️ Neither option works with the current architecture until the connection chain knowledge gap in Section 1 is resolved.**

Once the architecture is confirmed, the dynamic RLS pattern is:

1. Add a security table in the DW.

```sql
CREATE TABLE [Security].[User Permissions] (
    [User Permission Key] INT           NOT NULL IDENTITY(1,1),
    [User Principal Name] NVARCHAR(256) NOT NULL,   -- e.g. 'alice@org.ca'
    [Dimension Name]     NVARCHAR(128) NOT NULL,   -- e.g. 'Region'
    [Permitted Value]    NVARCHAR(256) NOT NULL,   -- e.g. 'East'
    CONSTRAINT [PK_Security_UserPermissions] PRIMARY KEY CLUSTERED ([User Permission Key])
);
```

2. Import `Security.User Permissions` into the SSAS model as a hidden table.
3. Apply a DAX role filter on the restricted dimension.

```dax
-- Option A: CALCULATETABLE pattern (standard)
-- Role filter on 'Dimension Region' table
[Region Code] IN
    CALCULATETABLE(
        VALUES( 'Security User Permissions'[Permitted Value] ),
        'Security User Permissions'[User Name] = USERNAME()
            && 'Security User Permissions'[Dimension Name] = "Region"
    )

-- Option B: TREATAS pattern (SQLBI preferred — no relationship required between security table and target dim)
-- Role filter on 'Dimension Region' table
COUNTROWS(
    TREATAS(
        CALCULATETABLE(
            VALUES( 'Security User Permissions'[Permitted Value] ),
            'Security User Permissions'[User Name] = USERNAME()
                && 'Security User Permissions'[Dimension Name] = "Region"
        ),
        'Dimension Region'[Region Code]
    )
) > 0
```

4. Assign the target Windows users or AD groups to one shared dynamic role.

## 4. Object-Level Security (OLS)

OLS hides tables or columns from a role.

- Define OLS in SSAS Tabular roles by setting the table or column permission to `None`.
- Use it to hide sensitive attributes such as payroll amounts or cost price.
- In Tabular Editor: right-click table or column → **Manage Roles** → set permission to `None`.

```json
{
  "name": "Role_SalesViewer",
  "modelPermission": "read",
  "tablePermissions": [
    {
      "name": "Fact HR Payroll",
      "columnPermissions": [
        { "name": "Gross Pay Amount", "metadataPermission": "none" }
      ]
    }
  ]
}
```

> OLS does not protect data in the underlying SQL tables; it protects only the SSAS model layer.

> **⚠️ Multi-role bypass:** SSAS Tabular combines role permissions using union (most-permissive-wins) semantics — the same rule as row-level security. If a user belongs to any other role that has `read` permission on the same table or column (even without an explicit OLS entry), the column becomes visible. With AD-group-driven role membership this is the most common OLS failure mode. OLS is only effective when the user has no other role granting access to the object.

## 5. PBIRS Folder Permissions

PBIRS organises reports by folder. Access is granted by assigning AD groups to PBIRS roles at the folder level.

| Role | Permissions |
|---|---|
| Browser | View reports and subscribe to reports |
| Content Manager | Full folder control, including publish, delete, and security management |
| Publisher | Upload reports and datasets |
| My Reports | Personal folder only |

Practical folder pattern:

```text
/Reports
  /Finance           → DL-PBIRS-Finance-Browser (Browser)
  /Operations        → DL-PBIRS-Operations-Browser (Browser)
  /HR                → DL-PBIRS-HR-Browser (Browser)
  /Admin             → DL-PBIRS-Admins (Content Manager)
```

```powershell
# Grant Browser access to an AD group on a PBIRS folder
# Requires PBIRS 2019+ REST API v2.0
$PBIRSServer = "https://your-pbirs-server/reports"
$FolderPath  = "/Finance"
$ADGroup     = "DOMAIN\\DL-PBIRS-Finance-Browser"
$RoleName    = "Browser"

$headers = @{ "Content-Type" = "application/json" }

# 1. Get folder item ID
$folder = Invoke-RestMethod -Uri "$PBIRSServer/api/v2.0/folders?`$filter=Path eq '$FolderPath'" `
    -UseDefaultCredentials -Headers $headers
$folderId = $folder.value[0].Id

# 2. Get role ID
$roles = Invoke-RestMethod -Uri "$PBIRSServer/api/v2.0/roles" `
    -UseDefaultCredentials -Headers $headers
$roleId = ($roles.value | Where-Object { $_.Name -eq $RoleName }).Id

# 3. Add policy
$body = @{
    GroupUserName = $ADGroup
    Roles = @(@{ Id = $roleId })
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Method Post `
    -Uri "$PBIRSServer/api/v2.0/folders($folderId)/Policies" `
    -UseDefaultCredentials -Headers $headers -Body $body
```

## 6. Tabular Editor Deployment — Role Management Checklist

```text
[ ] 1. Confirm SSAS connection authentication method (resolve knowledge gap — Section 1)
[ ] 2. Decide: fixed roles or dynamic RLS (see Section 3.3 vs 3.4)
[ ] 3. Define roles in Tabular Editor — commit BIM/JSON to git
[ ] 4. Assign AD groups/service accounts to roles in Tabular Editor
[ ] 5. Deploy model via CI/CD pipeline (roles are part of the BIM)
[ ] 6. Verify role membership in SSAS Management Studio:
       SSAS → Databases → [Model] → Roles
[ ] 7. Test role filter in DAX Studio:
       Set EffectiveUserName or CustomData to test user; verify row counts
[ ] 8. For fixed roles: update PBIRS data source connection strings to include Roles= property
[ ] 9. For dynamic RLS: populate [Security].[User Permissions] and verify DAX `USERNAME()` returns `DOMAIN\username` correctly under impersonation
[ ] 10. Document role design decision (fixed vs dynamic) in model README
```

## 7. Anti-Patterns

| Anti-Pattern | Why It Is a Problem |
|---|---|
| Granting individual Windows users to SSAS roles instead of AD groups | High maintenance; user churn makes access drift likely. |
| Using `sysadmin` or SSAS admin for the SSAS service account | Breaks least-privilege; SSAS admin can read any model. |
| Storing usernames in SSAS calculated columns for RLS | Non-performant; calculated columns evaluate at process time, not query time. |
| Mixing OLS and row-level security for the same restriction | Hard to reason about and harder to support. |
| Bypassing SSAS and letting PBIRS query DW tables directly | Skips the model security layer and widens SQL exposure. |
| Hardcoding AD group names in BIM | Group names change; keep operational mapping in documentation or deployment config. |
