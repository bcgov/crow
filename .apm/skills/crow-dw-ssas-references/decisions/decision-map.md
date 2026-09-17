# Source decision migration map

| Source decision | Crow status | Crow location or treatment |
|---|---|---|
| `org-design-constraints.md` | Migrated/adapted | `decisions/org-design-constraints.md`; explicitly scoped and loaded before technical references |
| `mode-reference-mapping.md` | Migrated/adapted | `reference-index.md` plus consumer-specific routing in each consuming `SKILL.md` |
| `model-selection-framework.md` | Adapted | Historical guidance only; Crow agents do not pin model versions. Host/session model policy controls runtime selection |
| `model-assignment-final.md` | Not operational | Historical assignments and obsolete version names are not copied into agent frontmatter |
| `nano-task-identification.md` | Deferred | Candidate rendering tasks remain future optimization work; no nano dependency is claimed |
| `follow-up-work.md` | Project-local | Validation interviews, cache experiments, and rollout metrics remain implementation/operations work, not package guidance |
| `TEMPLATE-decisions.md` | Owned by report designer | The report designer's `design/decisions.md` contract is the active Crow artifact |
| `TEMPLATE-glossary.md` | Owned by report designer | The report designer's `design/glossary.md` contract is the active Crow artifact |

Historical model prices, model IDs, and source-specific absolute paths are not
runtime instructions for the Crow package.
