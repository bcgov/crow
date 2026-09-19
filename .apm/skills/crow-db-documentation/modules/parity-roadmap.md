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
| D0-D3 database and Tabular documentation workflow | Adapted | `crow-db-documentation` agent and modules |
| SQL Server extended-property taxonomy, idempotent scripts, classifications, and D2 shared conventions | Adapted | `crow-db-documentation/modules/extended-properties.md`, `data-classification.md` |
| Documentation coverage, findings, session, confirmation, and apply contracts | Adapted | `crow-db-documentation/modules/workflow.md`, `contracts.md` |
| Nine-phase report-design interview and signed-off artifact contract | Adapted | `crow-report-designer` modules |
| Report-design to architecture/documentation handoffs | Adapted | `crow-report-designer/modules/handoff.md`, DB documentation contracts |
| Architect Modes A-G and P review routing | Adapted | `crow-ssas-tabular-dw-architect/modules/modes.md` |
| Architect Mode O physical-design review boundary | Adapted | architect mode and shared physical-design references |
| Mode C extended-property ownership | Adapted | `crow-db-documentation` |
| Kimball, Tabular, DAX, ELT, deployment, report, classification, and documentation corpus | Adapted | `crow-dw-ssas-references` |
| Organization design constraints (`org-design-constraints.md`) and report-design decision/glossary contracts | Adapted | `crow-dw-ssas-references/decisions`, `crow-report-designer/modules/interview.md`, `crow-report-designer/modules/handoff.md` |
| Source decision templates (`TEMPLATE-decisions.md`, `TEMPLATE-glossary.md`) as first-class workspace contracts | Adapted | `crow-report-designer/modules/interview.md`, `crow-report-designer/modules/handoff.md` |
| Explicit source analysis routing (`source-system-analysis.md`) and source→Crow routing/model artifact migration captured in consumer docs | Adapted | `crow-dw-ssas-references/reference-index.md`, `crow-ssas-tabular-dw-architect/modules/source-analysis.md` |
| PBIX/RDL deliverable classification trigger (Phase 8) | Adapted | `crow-report-designer/modules/interview.md`, `crow-report-designer/modules/handoff.md` (`deliverable_type` field) |
| External-documentation intake (data dictionaries, process maps, ERDs, wikis) cross-checked against repository evidence | Adapted | `crow-report-designer/modules/interview.md` |
| `business_requirements` / `pbirs_version` staleness re-confirmation (cadence-based, excludes model-preference tracking) | Adapted | `crow-report-designer/modules/interview-operations.md`, `crow-db-documentation/modules/workflow.md` |

## Concrete remaining work

| Work item | Status | Acceptance evidence |
|---|---|---|
| D0-D3 documentation fixtures and deterministic coverage/output checks | Adapted | Public local SQL/SSDT/TMDL fixtures exercise coverage, resume, append, skip, and apply-gate behavior |
| Report designer session, write-gate, phase-resume, and signed-off handoff tests | Adapted | Existing valid/invalid handoff and paused-session fixtures retained as structured contract examples |
| Architect A-G, O, and P review fixtures | Adapted | Representative local inputs verify mode routing, completion shape, findings, and unsupported/deferred reporting |
| Cross-agent handoff compatibility checks | Adapted | Producer/consumer versioned payloads validate required artifacts, status, grain, bus matrix, and confirmation fields |
| Modes H-I scaffold artifact contracts and validators | Adapted | Deterministic output schemas and checks for SSDT/DW and TMDL/Tabular scaffolds |
| Modes J-M generated artifact contracts and validators | Adapted | Checks for source procedures, SSIS catalog JSON, DAX definitions, and Classic ADO configuration |
| Mode N ordered build manifest and prerequisite gates | Adapted | Non-executing orchestration manifest validates H-M dependencies and stops on failed prerequisites |
| Mode N bus-matrix and documentation dependencies | Adapted | Manifest validates Mode E bus-matrix approval and Mode C DB-documentation handoff prerequisites before H-M |
| D3 BIM/TMDL supported-surface fixtures | Adapted | Local fixtures prove table/column/measure descriptions, relationship metadata handling, and unsupported surfaces are reported |
| Mode P CSV and manual source profiling | Adapted | Local CSV/sample/manual fixtures produce an entity map without inventing database metadata |
| Mode P CSV/manual discovery split and low-confidence inferred relationships | Adapted | Preserve the source project’s explicit Path B/Path C handling and the separate inferred-relationships section for non-SQL or no-FK sources |

## Explicitly outside this register

- live SQL/SSAS/Raven providers and authentication (a repo-wide Crow platform
  pattern — see `crow-db-documentation/modules/contracts.md` and
  `crow-ssas-tabular-dw-architect/modules/provider-boundaries.md` — not a gap
  introduced by this migration; the actual review/generation behavior
  (Modes A-P, references) is bundled directly in this package via
  `crow-dw-ssas-references` and `crow-ssas-tabular-dw-architect`, so no
  external skill dependency is required or missing);
- deployment, processing, pipeline, or build execution;
- new database-provider adapters;
- research spikes or unknown-problem investigations;
- model pinning, caching, nano optimization, and cost experiments.

## Pre-retirement item (open, tracked)

- **Live SQL/SSAS discovery provider contract**: the user has decided this
  needs a drafted plan (not silent deferral) before `CopilotDWTools` is
  retired. See `crow-ssas-tabular-dw-architect/modules/provider-contract-plan.md`
  for scope, required contract elements, and acceptance criteria. Status:
  planned, not started — retirement should wait for either a reviewed
  contract or an explicit decision to proceed without one.

## Minor polish (non-blocking)

- Add a handoff-fixture/validator check that rejects a missing or invalid
  `deliverable_type` (must be `pbix`, `rdl`, or `both`) in
  `crow-report-designer/modules/handoff.md` consumers.
- Define a canonical `design/decisions.md` row shape (`value`,
  `last_confirmed`, `cadence_days`, `source/owner`) for the
  `business_requirements`/`pbirs_version` staleness mechanism so agents record
  compatible rows.

The source project's historical model-selection artifacts and research spikes are
intentionally not copied as package instructions. The useful parts were
retained through agent guidance, `reference-index.md`, and the active
workspace contracts for `design/spec.md`, `design/decisions.md`,
`design/glossary.md`, `design/bus-matrix.md`, and `design/entity-map.md`.
`model-selection-framework.md` and `model-assignment-final.md` are adapted into
runtime model guidance, not copied verbatim.

Those items may become separate product work later, but they are not required
to complete the migrated Crow capability set.

## Completion rule

Remove a row only after the stated acceptance evidence exists and the relevant
Crow validator/package checks pass. Do not claim a generated artifact or
runtime action was executed when only a contract, plan, or validator exists.
