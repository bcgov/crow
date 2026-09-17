---
name: crow-report-designer
description: Route nine-phase requirements interviews, source profiling, signed-off DW report design artifacts, and conditional dimensional-review handoffs.
---

# Crow report designer

Activate for SQL Server DW, SSAS Tabular, Power BI Report Server, or dimensional report requirements. Load only the needed modules:

- [`modules/interview.md`](modules/interview.md) for the nine-phase gate and artifact contract.
- [`modules/interview-operations.md`](modules/interview-operations.md) for
  session resume, deferral classification, phase gates, and grain
  stress-testing.
- [`modules/source-profile.md`](modules/source-profile.md) for local SQL/SSDT/TMDL profiling and Mode P handoff.
- [`modules/handoff.md`](modules/handoff.md) for bus matrix, glossary, sign-off, and collaborator boundaries.
- [`../crow-dw-ssas-references/SKILL.md`](../crow-dw-ssas-references/SKILL.md)
  and its [`reference-index.md`](../crow-dw-ssas-references/reference-index.md)
  for source-backed guidance. Route references deterministically:
  requirements/grain/bus matrix -> `kimball-patterns.md`, `dw-calendar-build.md`;
  source profiling -> `source-system-analysis.md`, `dw-validation-patterns.md`;
  report constraints -> `pbirs-constraints.md`, `pbix-report-standards.md`;
  security/performance -> `security-implementation.md`,
  `performance-end-to-end.md`; handoff/build assumptions ->
  `ssdt-project-structure.md`. Load only the selected files.
  When the source organization standard is confirmed, load
  `../crow-dw-ssas-references/decisions/org-design-constraints.md` before
  applying Kimball or build guidance.

Use [`crow-project-context`](../crow-project-context/SKILL.md) only when public
project memory is relevant; use [`crow-business-rules`](../crow-business-rules/SKILL.md),
[`crow-application-architecture`](../crow-application-architecture/SKILL.md),
[`crow-testing`](../crow-testing/SKILL.md), or
[`crow-release`](../crow-release/SKILL.md) only for an explicit related
concern. Live providers and build execution remain conditional.
