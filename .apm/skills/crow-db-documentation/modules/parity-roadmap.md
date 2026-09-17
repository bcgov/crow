# DB Documenter parity roadmap

Load this module only when planning or reviewing parity with
`CopilotDWTools`. It is a maintainer-facing register, not a promise that
deferred capabilities are available in the current Phase 1 agent.

## Status meanings

- **Migrated**: behavior is represented in the Crow agent or routed modules.
- **Adapted**: the behavior is preserved with a Crow-specific boundary or
  safer local-first implementation.
- **Deferred**: intentionally outside Phase 1 and requires a later design or
  provider capability.
- **Owned elsewhere**: the behavior belongs to another Crow capability and
  should be integrated through a narrow handoff, not copied here.
- **Rejected**: intentionally not carried forward because it conflicts with
  Crow boundaries or public-release requirements.

## Source capability register

| Source capability | Status | Current Crow location or owner | Remaining work |
|---|---|---|---|
| D0 database/schema context | Adapted | `modules/workflow.md`, `modules/extended-properties.md` | Validate against representative local fixtures. |
| D1 source SQL documentation | Adapted | `modules/workflow.md`, `modules/sql-server.md`, `modules/extended-properties.md` | Add deterministic local inventory and coverage checks. |
| D2 DW documentation and property baseline | Adapted | `modules/extended-properties.md`, `modules/data-classification.md` | Add fixture-backed completeness tests and confirm project-specific extensions interactively. |
| D3 Tabular documentation | Adapted | `modules/tabular.md` | Define and test the supported TMDL/BIM surface; explicitly classify XMLA/DMV as deferred. |
| Interview, draft, confirmation, conflict, and apply gates | Adapted | `crow-db-documenter.agent.md`, `modules/workflow.md` | Add reusable batch/output templates if multiple producers need the same shapes. |
| Coverage, findings, and session outputs | Adapted | `modules/workflow.md`, `modules/contracts.md` | Define machine-checkable schemas without making generated project artifacts package content. |
| Convention detection and persistence | Adapted | `modules/workflow.md`, `modules/extended-properties.md` | Add a deterministic convention inventory only where stable inputs and outputs are clear. |
| Session pause/resume and append-only history | Adapted | `modules/workflow.md` | Exercise against synthetic prior-session fixtures. |
| Inference heuristics | Adapted | `modules/extended-properties.md`, `modules/tabular.md` | Consolidate reusable heuristics if D1/D2/D3 duplication emerges; do not infer sensitivity silently. |
| SQL Server native sensitivity classification | Migrated | `modules/data-classification.md` | Validate scripts and permissions against supported SQL Server versions when a test fixture exists. |
| Direct live SQL/SSAS discovery | Deferred | Future Raven/provider boundary in `modules/contracts.md` | Define provider-neutral inventory/result contracts after Raven exposes a reviewed capability. |
| Future database providers | Deferred | Agent boundary and `modules/contracts.md` | Specify adapter contract and normalized inventory shape before implementation. |
| Raven authentication, query, and tool names | Deferred | `modules/contracts.md` | Do not invent an API; adopt the reviewed Raven contract when available. |
| Report-design and DW/SSAS-architect handoffs | Adapted | `modules/contracts.md`, `crow-report-designer`, `crow-ssas-tabular-dw-architect` | Validate versioned payloads with representative fixtures before declaring parity. |
| Optional business-rule context/output handoff | Adapted | `modules/contracts.md` | Add compatibility tests only if both capabilities expose versioned artifacts. |
| Deterministic inventory, audit, script, and schema validation | Deferred | No Phase 1 scripts | Decide execution authority, then add narrowly scoped scripts with non-zero failure behavior. |
| DW architecture, DAX, ELT, pipeline, report design, and deployment generation | Owned elsewhere | Dimensional-review/report-design capabilities | Keep out of DB Documenter; use handoffs where documentation context is needed. |
| Source-specific organization values, private paths, and live evidence | Rejected | Public-release hygiene | Keep project-local and never package or commit as reusable guidance. |

## Phase 2 parity register

Phase 1 remains the DB Documenter's documentation boundary. Phase 2 adds
report requirements and DW/SSAS architecture orchestration around it; it does
not transfer DB metadata policy, live-provider authority, or build execution
into the DB Documenter. Phase 2 handoffs consume the Phase 1 documentation
contract only after explicit sign-off or user-selected documentation scope.

| Source capability | Status | Current Crow location | Remaining work |
|---|---|---|---|
| Report-design interview and signed-off artifact contract | Adapted | `crow-report-designer` | Add representative fixture validation for write gates, phase resume, and signed-off handoff. |
| Source profiling and entity-map handoff | Adapted | `crow-report-designer/modules/source-profile.md` | Validate normalized payloads and live-provider limitation reporting with fixtures. |
| Architect Modes A–G and P review routing | Adapted | `crow-ssas-tabular-dw-architect/modules/modes.md` | Add focused mode fixtures and complete topic-specific review modules. |
| Architect Modes H–N scaffold/build planning | Deferred | `crow-ssas-tabular-dw-architect/modules/modes.md` | Migrate detailed artifact contracts, validation gates, and deterministic generators without claiming execution. |
| Architect Mode O physical design review | Deferred | `crow-ssas-tabular-dw-architect/modules/modes.md` | Add index/partition/statistics guidance and local validation. |
| Architect Mode C extended-property generation | Owned elsewhere | `crow-db-documentation/modules/extended-properties.md` | Define the explicit request/response boundary and compatibility fixture. |
| Refresh/performance architect notes | Adapted | `crow-report-designer/modules/interview.md`, `modules/handoff.md` | Validate capture and consumption by the architect. |
| Report-designer session operations and deferral protocol | Adapted | `crow-report-designer/modules/interview-operations.md` | Add fixture-backed resume and blocking/advisory gate validation. |
| Architect provider and execution boundary | Adapted | `crow-ssas-tabular-dw-architect/modules/provider-boundaries.md` | Replace deferred placeholders only after Raven/execution contracts are reviewed. |
| Architect technical reference catalogue | Adapted | `crow-dw-ssas-references/reference-index.md`, `crow-ssas-tabular-dw-architect/modules/reference-map.md` | Validate selected references against representative fixtures and keep provider/execution claims deferred. |
| Source decision register and organization constraints | Adapted | `crow-dw-ssas-references/decisions/` | Confirm which source-organization conventions apply to each consuming project; keep historical model pins and rollout metrics non-operative. |

## Recommended delivery order

1. Add synthetic fixtures and focused tests for D0-D3 coverage, resume, and
   output append behavior.
2. Define stable coverage, findings, session, and provider inventory shapes.
3. Add deterministic local inventory/audit scripts only after the agent's
   execution authority and failure contract are approved.
4. Review the D3 TMDL/BIM/XMLA boundary and the future Raven adapter contract.
5. Re-run authoring, review, rubber-duck, package, and release validation before
   promoting parity claims or changing the major capability boundary.

Parity work must not be reported as complete merely because a draft, script,
or handoff was proposed. Each item needs representative evidence, an explicit
status change, and validation appropriate to its output.
