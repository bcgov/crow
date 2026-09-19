# Reference index and routing

The files in `references/` are the complete 28-file reference corpus migrated
from the source project. Load them selectively by observable mode or concern.
Source decision handling is recorded in
[`decisions/org-design-constraints.md`](decisions/org-design-constraints.md);
load it before technical references when that standard is confirmed. That
file is the active decision surface and may be overridden by explicit user
direction or stronger project evidence.

| Reference | Load for | Consumers |
|---|---|---|
| `kimball-patterns.md` | facts, dimensions, grain, SCD, bus matrix, bridges | report designer, architect |
| `kimball-advanced-patterns.md` | late-arriving facts, snapshots, Data Vault bridges | architect |
| `sqlbi-dax-patterns.md` | standard DAX measures and time intelligence | architect |
| `sqlbi-dax-patterns-advanced.md` | advanced DAX, M2M, disconnected tables, aggregations | architect |
| `sqlbi-dax-patterns-niche.md` | niche DAX patterns only when directly relevant | architect |
| `dax-style-guide.md` | DAX naming, formatting, VAR/RETURN, descriptions | architect |
| `dax-studio-workflow.md` | performance analysis and Server Timings | architect |
| `ssas-tabular-bp.md` | Tabular structure, relationships, partitions, BPA | architect, DB Documenter D3 |
| `tabular-editor-2-automation.md` | local TE2 scripts and BPA automation | architect |
| `ssas-deployment-processing.md` | processing and deployment planning | architect |
| `dw-review-checklist.md` | end-to-end review findings and severity | architect |
| `dw-validation-patterns.md` | local or reviewed-provider DW validation | architect |
| `dw-physical-design.md` | indexes, statistics, partitioning, staging | architect Mode O |
| `performance-end-to-end.md` | DW-to-model-to-report performance | report designer, architect |
| `dw-calendar-build.md` | calendar dimension design | report designer, architect |
| `source-system-analysis.md` | source entity profiling, candidate classification, CSV/manual discovery, inferred relationships | report designer, architect |
| `elt-patterns.md` | staging, load SPs, ELT controls, SSIS structure | architect |
| `ssisdb-catalog-config.md` | SSIS catalog/environment configuration | architect |
| `ssdt-project-structure.md` | SSDT layout, DACPAC, publish profiles | report designer, architect, DB Documenter |
| `devops-deployment-patterns.md` | ADO Server deployment planning | architect |
| `devops-operations-patterns.md` | pipeline operations and PowerShell standards | architect |
| `pbirs-constraints.md` | PBIRS-supported report features and limits | report designer, architect |
| `pbix-report-standards.md` | report conventions and freshness/debug patterns | report designer |
| `security-implementation.md` | SSAS roles, RLS/OLS, PBIRS-to-SSAS chain | report designer, architect |
| `data-classification.md` | SQL Server native sensitivity classification | DB Documenter, architect |
| `extended-properties-templates.md` | SQL Server metadata scripts | DB Documenter, architect Mode C |
| `documentation-authoring.md` | coverage, inference, interviews, findings | DB Documenter |
| `cloud-migration-portability.md` | advisory on-prem/cloud portability | report designer, architect |

The source corpus contains project-specific conventions and deferred execution
examples. Use the content as reference, not as proof that a provider,
toolchain, credential, server, path, or deployment target exists in the
reviewed project.
