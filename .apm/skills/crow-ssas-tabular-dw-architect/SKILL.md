---
name: crow-ssas-tabular-dw-architect
description: Route Mode A-P local-first dimensional, SSAS Tabular/TMDL, DAX, source, ELT, deployment, and conditional build reviews.
---

# Crow SSAS Tabular DW Architect

Load [`modules/modes.md`](modules/modes.md) for routing and boundaries, then only the relevant topic module:
`kimball.md`, `tabular-dax.md`, `source-analysis.md`, or `elt-deployment.md`.
Load [`modules/provider-boundaries.md`](modules/provider-boundaries.md) when a
live provider, execution contract, or fallback decision is discussed.
Load [`modules/reference-map.md`](modules/reference-map.md) when selecting
legacy technical guidance or assessing parity.
Load the shared [`crow-dw-ssas-references` skill](../crow-dw-ssas-references/SKILL.md)
and [`reference-index.md`](../crow-dw-ssas-references/reference-index.md) for
the detailed source-backed pattern files. Route A/E/H/O to
`kimball-patterns.md`, `kimball-advanced-patterns.md`, `dw-review-checklist.md`,
`dw-physical-design.md`, and `dw-validation-patterns.md`; B/D/I/L to
`ssas-tabular-bp.md`, `sqlbi-dax-patterns.md`, `sqlbi-dax-patterns-advanced.md`,
`dax-style-guide.md`, and `dax-studio-workflow.md`; F/J/K/M/N to
`elt-patterns.md`, `ssisdb-catalog-config.md`, `ssdt-project-structure.md`,
`ssas-deployment-processing.md`, and `devops-deployment-patterns.md`; P to
`source-system-analysis.md`; report-facing concerns to
`pbirs-constraints.md`, `pbix-report-standards.md`, and
`performance-end-to-end.md`. Load only the selected files.
When the source organization standard is confirmed, load
`../crow-dw-ssas-references/decisions/org-design-constraints.md` before the
topic reference. It governs SCD defaults, Tabular-only scope, ELT/upstream-first
design, idempotency, Classic ADO/TE2 conventions, and portability constraints.
Use [`crow-db-documentation`](../crow-db-documentation/SKILL.md) for the
DB-documenter handoff; use [`crow-report-designer`](../crow-report-designer/SKILL.md)
for a report design handoff. Other Crow skills are opt-in, not automatic.
