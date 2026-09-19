<!-- Crow portability note: migrated reference guidance; validate project-specific conventions and treat paths, versions, and platform choices as examples unless local evidence confirms them. -->

# Cloud Migration Portability Reference

## Purpose

This reference documents the on-premises → cloud mapping for the organisation's BI stack. It is **advisory** — cloud portability is a preference that informs technology choices where alternatives are equally viable, but it does not block or constrain on-premises delivery.

This file is routed through
`.apm/skills/crow-dw-ssas-references/reference-index.md` and consumed by the
Crow report designer and SSAS/DW architect when portability is in scope.

---

## Design Philosophy

The organisation has chosen technologies that preserve a viable cloud migration path (Microsoft Fabric / Azure), so that if/when a move to cloud is decided, the investment in on-premises artifacts is not lost:

- **Tabular over Multidimensional** — Multidimensional has no cloud path; Tabular imports directly to Fabric
- **T-SQL stored procedures over SSIS transforms** — SPs are portable; SSIS Data Flow is not
- **SSIS as orchestrator only** — ADF replaces orchestration trivially; the SPs do the real work
- **Entra ID for authentication** — already cloud-ready; same identity provider on-prem and cloud
- **TMDL as model format** — native serialisation for Fabric semantic models
- **Live connection (not Import mode)** — reports connect to the semantic model; the model owns the data

## Current Infrastructure (already cloud-ready)

These choices are already in place and require no migration work:

- Entra ID authentication (AD groups synced to Entra)
- T-SQL stored procedures for all ELT transformation
- MERGE and set-based operations (GA in Fabric Warehouse)
- SSIS packages use Execute SQL Task only (no Data Flow, no Script Tasks)
- SQL Agent Job = one job calling one SSIS orchestrator package + SSAS processing
- Self-contained DW databases (no cross-database queries, no linked servers)
- No CLR assemblies, xp_cmdshell, OPENROWSET, Database Mail, or Service Broker
- SQL Server 2022 (upgrading to 2025 by end of 2026)
- BIML Express for package generation (BIML Flex is the cloud-capable equivalent from Varigence)

---

## Portability Matrix

| # | On-Premises (Current) | Cloud Equivalent (Future) | Migration Effort | Notes |
|---|---|---|---|---|
| 1 | **SSAS Tabular** (DAX, live connection) | Fabric / Power BI Premium semantic models | Low | TMDL imports directly. DAX is identical. Live connection works against Fabric endpoints. |
| 2 | **SQL Server DW** (T-SQL, stored procedures, MERGE) | Azure SQL DB / Azure SQL MI / Fabric Warehouse | Low | T-SQL is portable. MERGE is GA in Fabric Warehouse. Schema DDL transfers directly via DacPac. |
| 3 | **SSIS** (orchestration only — Execute SQL Task, Execute Process Task) | Azure Data Factory / Fabric Pipelines | Low | ELT logic lives in SPs. ADF replaces orchestration with Execute SQL Task equivalents and pipeline triggers. |
| 4 | **Power BI Report Server** (.pbix, live connection) | Power BI Service / Fabric | Low | .pbix files deploy to either target. Live connection works identically. Feature set expands in cloud (dashboards, Q&A, subscriptions, Copilot). |
| 5 | **Azure DevOps Server** (on-prem, Classic pipelines) | Azure DevOps Services (cloud) | Low | Same YAML/Classic pipelines, same Git repos. Migration is a project import. |
| 6 | **SSDT / Visual Studio DB Projects** | Same (SqlPackage CLI) | None | DacPac deployment works against Azure SQL and Fabric Warehouse. |
| 7 | **Tabular Editor 2.x** (TMDL) | Tabular Editor 3 / TMDL native in Fabric | Low | TMDL is Fabric's native format. TE3 adds Fabric workspace connectivity. |
| 8 | **SQL Server Agent Jobs** (ELT scheduling) | Azure SQL MI → MI SQL Agent (1:1). Azure SQL DB → Elastic Jobs. Fabric → Fabric Pipelines / ADF triggers. | Low–Medium | Current pattern (one job = one SSIS package + SSAS processing) maps cleanly. Only the trigger mechanism changes; SPs don't change. |
| 9 | **BIML Express** (SSIS package generation) | BIML Flex (Varigence) | Low | BIML Flex targets ADF, Fabric Pipelines, and other orchestrators. Same metadata-driven approach, different output target. |
| 10 | **Entra ID** (authentication) | Entra ID (cloud-native) | None | Already cloud-ready. Same identity provider, same groups. Assumes AD group sync to Entra is in place. |
| 11 | **Extended Properties** (MS_Description, org properties) | Azure SQL/MI: same. Fabric Warehouse: verify current support (may be limited to MS_Description). | Low–Medium | Extended properties work in Azure SQL/MI. For Fabric Warehouse, documentation may shift to Microsoft Purview or TMDL descriptions. Verify against current Fabric docs before migration. |

---

## What Is Already Cloud-Ready (No or Minimal Migration Work)

These choices mean minimal refactoring if the org decides to migrate:

- **Entra ID authentication** — same identity provider on-prem and cloud (assumes AD group sync is in place)
- **T-SQL stored procedures** — run on Azure SQL / MI with minimal changes; validate against Fabric Warehouse T-SQL surface area if targeting Fabric
- **MERGE statements** — GA in Fabric Warehouse
- **DacPac deployments** — SqlPackage targets Azure SQL / MI
- **TMDL model definitions** — Fabric's native format
- **.pbix report files** — deploy to PBI Service (validate Desktop version compatibility; gateway/SSO setup needed for hybrid scenarios)
- **DAX measures** — identical engine in Fabric semantic models
- **Git repositories** — ADO Server → ADO Services is a project import

---

## Patterns to Prefer (Maximize Portability)

When designing new solutions and multiple approaches are equally viable, prefer:

| Pattern | Why |
|---|---|
| T-SQL stored procedures for all transformation logic | SPs run on Azure SQL, MI, and (with T-SQL surface area validation) Fabric Warehouse. SSIS Data Flow transforms have no cloud equivalent. |
| MERGE and set-based operations | Supported in Fabric Warehouse. Performant and portable. |
| SSIS as orchestrator only (Execute SQL Task) | ADF Execute SQL activity replaces this 1:1. Avoid SSIS Data Flow, Script Tasks, custom components. |
| Parameters for all environment-specific values | Enables same artifact across DEV/TEST/UAT/PROD and future cloud environments. |
| Tabular Editor TMDL for model definitions | Native Fabric format. Avoid .bim-only workflows. |
| AD groups for security (via Entra ID) | Same groups work in Fabric workspaces and PBI Service. |
| SQL Agent Jobs as simple schedulers (call one SP or one SSIS package) | Easy to replace with ADF trigger + Execute SQL. Complex multi-step Agent Jobs are harder to migrate. |
| Extended properties for documentation | Works in Azure SQL. Provides the documentation foundation that transfers to Purview metadata if moving to Fabric Warehouse. |

---

## Patterns to Avoid (Migration Risks)

When reviewing existing infrastructure or designing new solutions, **flag these as portability risks**:

| Anti-Pattern | Why It's a Risk | Cloud Alternative |
|---|---|---|
| **SSIS Data Flow transforms** (Script Tasks with C#, Lookup/Merge Join in data flow, custom components) | No ADF equivalent. Requires complete rewrite. | Move logic to T-SQL SPs; use SSIS only for orchestration. |
| **Cross-database queries** (3-part or 4-part names: `[OtherDB].[dbo].[Table]`) | Not supported in Azure SQL DB. Requires Elastic Query or architecture change. Azure SQL MI supports it within the same instance. | Design SPs to operate within a single database. Use staging tables for cross-DB data movement. |
| **Linked Servers** | Deprecated path. TLS enforcement breaks legacy configurations. Not available in Azure SQL DB. | Replace with SSIS source extraction SPs that pull data into staging. |
| **CLR assemblies** in SQL Server | Supported in Azure SQL MI (SAFE only), not in Azure SQL DB, not in Fabric Warehouse. | Replace with T-SQL or move logic to Azure Functions called via `sp_invoke_external_rest_endpoint`. |
| **`xp_cmdshell`** | Not available in any cloud target. | Replace with PowerShell in pipeline steps or Azure Automation runbooks. |
| **`OPENROWSET` / `BULK INSERT`** from local file paths | File system not available in cloud. | Use ADF Copy Activity for file ingestion. Stage files in blob storage. |
| **Complex multi-step SQL Agent Jobs** (dozens of steps with conditional logic) | Hard to replicate in ADF/Fabric. Simple jobs (1 step = 1 SP call) migrate trivially. | Keep Agent Jobs simple: one job = one SP or one SSIS package call. Complex orchestration goes in SSIS (which maps to ADF). |
| **Database Mail / `sp_send_dbmail`** | Not available in Azure SQL DB. Limited in MI. | Replace with Logic Apps, Power Automate, or ADF pipeline failure alerts. |
| **Service Broker** | Not available in Azure SQL DB. Available in MI with limitations. | Replace with Azure Service Bus or event-driven patterns. |
| **`text` / `ntext` / `image` data types** | Deprecated. Blocked in newer compatibility levels. | Use `varchar(max)` / `nvarchar(max)` / `varbinary(max)`. |
| **Old-style joins** (`*=`, `=*`) and deprecated RAISERROR syntax | Blocked in modern compatibility levels. | Use ANSI JOIN syntax and modern error handling. |
| **Third-party SSIS components** (e.g., KingswaySoft, CozyRoc) for transforms | No cloud equivalent for the component itself. | Use the component only for source extraction (staging). Never for transformation logic. |

---

## PBIRS → Power BI Service: Feature Expansion

When migrating reports from PBIRS to PBI Service, the .pbix files are portable but migration is not zero-effort:
- Validate Power BI Desktop version compatibility (Report Server edition vs latest)
- Gateway + SSO configuration required if semantic model stays on-prem during transition
- Custom visuals and tenant settings may need review
- Subscription/alert features need setup (don't exist on-prem)

Features that become available in PBI Service (not available on PBIRS):

| Feature | Impact |
|---|---|
| Dashboards | New artifact type; pin visuals from multiple reports |
| Q&A (natural language) | End users can ask questions in plain language |
| Email subscriptions & alerts | Automated report delivery |
| Deployment pipelines & Git integration | DevOps for report lifecycle |
| Copilot / AI features | Requires F64+ capacity |
| Real-time streaming | Push datasets, live dashboards |
| Personalize visuals | End users can change chart types without editing |
| Analyze in Excel | Direct connection from Excel |
| Direct Lake mode | For Fabric-native data — bypasses Import refresh |

**Design implication**: Features designed for PBIRS (e.g., Debug/Data Freshness tabs, manual refresh indicators) may become unnecessary in cloud where refresh is continuous and monitoring is built-in. They don't break — they just become redundant.

---

## SSAS Tabular → Fabric Semantic Model: What Transfers

| Aspect | Transfers directly? | Notes |
|---|---|---|
| Tables, columns, relationships | ✅ Yes | TMDL import |
| DAX measures | ✅ Yes | Identical engine |
| Calculation groups | ✅ Yes | Supported in Fabric |
| RLS roles (TREATAS / table filters) | ✅ Yes | Same DAX-based RLS |
| Partitions | ⚠️ Adjust | Fabric uses different partition strategies (Direct Lake segments vs Import partitions) |
| Processing/refresh schedules | ❌ Redesign | Fabric uses semantic model refresh or Direct Lake (no processing needed) |
| Perspectives | ✅ Yes | Supported |
| Descriptions (TMDL `description:`) | ✅ Yes | Transfer as-is |
| Annotations (e.g., `BusinessDescription` on relationships) | ✅ Yes | TOM annotations are preserved |
| OLS (Object-Level Security) | ✅ Yes | Supported in Fabric Premium |

---

## Review Checklist — Portability Assessment

When reviewing an existing DW or SSAS model (architect Mode A), include a **Portability Assessment** if any of the following are detected:

- [ ] Cross-database queries (3/4-part names) in stored procedures
- [ ] Linked Server references
- [ ] CLR assembly usage
- [ ] `xp_cmdshell` calls
- [ ] `OPENROWSET` / `BULK INSERT` from file paths
- [ ] SSIS Data Flow transforms (not just Execute SQL Task)
- [ ] Complex Agent Jobs (> 3 steps with conditional logic)
- [ ] Database Mail dependencies
- [ ] Service Broker usage
- [ ] `text` / `ntext` / `image` columns
- [ ] Third-party SSIS components used for transformation (not just extraction)
- [ ] Hard-coded server/database names (not parameterised)
- [ ] Authentication patterns that bypass Entra ID (verify all connections use Entra ID, not legacy SQL auth or local Windows accounts)

**Severity for portability findings:**
- 🟡 Low — easy workaround exists, < 1 day effort per occurrence
- 🟠 Medium — requires design change, 1–5 days effort
- 🔴 High — requires architectural rethink, > 5 days effort or blocks migration without redesign

These findings are informational — not blockers for the current review. They inform future cloud migration planning.
