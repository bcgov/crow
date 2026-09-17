# DW/SSAS capability completion register

This maintainer-facing register tracks concrete work remaining in the three
Crow capabilities. It is not a copy of a retired project plan. Research
spikes, unknown-provider exploration, model-cost experiments, and live
execution are intentionally excluded from this register.

## Status meanings

- **Complete**: behavior and guidance are represented in Crow.
- **Complete — validate**: implementation is present; representative fixtures
  or deterministic checks remain.
- **Planned**: concrete implementation work remains.
- **Owned**: another Crow capability is the authoritative owner.

## Completed capability areas

| Capability | Status | Crow location |
|---|---|---|
| D0-D3 database and Tabular documentation workflow | Complete | `crow-db-documentation` agent and modules |
| SQL Server extended-property taxonomy, idempotent scripts, classifications, and D2 shared conventions | Complete | `crow-db-documentation/modules/extended-properties.md`, `data-classification.md` |
| Documentation coverage, findings, session, confirmation, and apply contracts | Complete | `crow-db-documentation/modules/workflow.md`, `contracts.md` |
| Nine-phase report-design interview and signed-off artifact contract | Complete — validate | `crow-report-designer` modules |
| Report-design to architecture/documentation handoffs | Complete — validate | `crow-report-designer/modules/handoff.md`, DB documentation contracts |
| Architect Modes A-G and P review routing | Complete — validate | `crow-ssas-tabular-dw-architect/modules/modes.md` |
| Architect Mode O physical-design review boundary | Complete | architect mode and shared physical-design references |
| Mode C extended-property ownership | Owned | `crow-db-documentation` |
| Kimball, Tabular, DAX, ELT, deployment, report, classification, and documentation corpus | Complete | `crow-dw-ssas-references` |
| Organization design constraints and decision handling | Complete | `crow-dw-ssas-references/decisions` |

## Concrete remaining work

| Work item | Status | Acceptance evidence |
|---|---|---|
| D0-D3 documentation fixtures and deterministic coverage/output checks | Planned | Public local SQL/SSDT/TMDL fixtures exercise coverage, resume, append, skip, and apply-gate behavior |
| Report designer session, write-gate, phase-resume, and signed-off handoff tests | Complete — validate | Existing valid/invalid handoff and paused-session fixtures still need executable assertions |
| Architect A-G, O, and P review fixtures | Planned | Representative local inputs verify mode routing, completion shape, findings, and unsupported/deferred reporting |
| Cross-agent handoff compatibility checks | Planned | Producer/consumer versioned payloads validate required artifacts, status, grain, bus matrix, and confirmation fields |
| Modes H-I scaffold artifact contracts and validators | Planned | Deterministic output schemas and checks for SSDT/DW and TMDL/Tabular scaffolds |
| Modes J-M generated artifact contracts and validators | Planned | Checks for source procedures, SSIS catalog JSON, DAX definitions, and Classic ADO configuration |
| Mode N ordered build manifest and prerequisite gates | Planned | Non-executing orchestration manifest validates H-M dependencies and stops on failed prerequisites |
| Mode N bus-matrix and documentation dependencies | Planned | Manifest validates Mode E bus-matrix approval and Mode C DB-documentation handoff prerequisites before H-M |
| D3 BIM/TMDL supported-surface fixtures | Planned | Local fixtures prove table/column/measure descriptions, relationship metadata handling, and unsupported surfaces are reported |
| Mode P CSV and manual source profiling | Planned | Local CSV/sample/manual fixtures produce an entity map without inventing database metadata |

## Explicitly outside this register

- live SQL/SSAS/Raven providers and authentication;
- deployment, processing, pipeline, or build execution;
- new database-provider adapters;
- research spikes or unknown-problem investigations;
- model pinning, caching, nano optimization, and cost experiments.

Those items may become separate product work later, but they are not required
to complete the migrated Crow capability set.

## Completion rule

Remove a row only after the stated acceptance evidence exists and the relevant
Crow validator/package checks pass. Do not claim a generated artifact or
runtime action was executed when only a contract, plan, or validator exists.
