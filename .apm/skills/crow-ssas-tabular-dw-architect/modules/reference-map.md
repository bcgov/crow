# Architect reference map

Use this map to select knowledge without loading the legacy reference
directory wholesale. The current Crow package contains routing boundaries, not
copied source-project evidence.

| Concern | Legacy source reference | Crow status |
|---|---|---|
| Kimball facts, dimensions, SCD, grain, bus matrix | `references/kimball-patterns.md`, `references/kimball-advanced-patterns.md` | Packaged and routed; use with `kimball.md` |
| DAX patterns and style | `references/sqlbi-dax-patterns*.md`, `references/dax-style-guide.md` | Packaged and routed; use with `tabular-dax.md` |
| SSAS Tabular BPA, relationships, partitions, roles | `references/ssas-tabular-bp.md`, `references/security-implementation.md` | Packaged and routed; use with `tabular-dax.md` |
| DW review and validation | `references/dw-review-checklist.md`, `references/dw-validation-patterns.md` | Packaged and routed; local fixture validation remains separate |
| ELT and SSIS | `references/elt-patterns.md`, `references/ssisdb-catalog-config.md` | Packaged and routed; generated artifact contracts remain deferred |
| SSDT and deployment | `references/ssdt-project-structure.md`, `references/devops-deployment-patterns.md`, `references/devops-operations-patterns.md` | Packaged and routed; execution remains deferred |
| Physical design and performance | `references/dw-physical-design.md`, `references/performance-end-to-end.md` | Packaged and routed for Mode O; execution remains deferred |
| Source profiling | `references/source-system-analysis.md` | Packaged and routed; fixture validation remains separate |
| Debug tab / data-freshness scaffold pattern (Mode I) | `references/pbix-report-standards.md` | Packaged and routed; report designer is primary consumer, architect loads it for Mode I scaffolds |

The full corpus is owned by
`.apm/skills/crow-dw-ssas-references/reference-index.md`; load it selectively
and do not treat reference guidance as project evidence or execution authority.
