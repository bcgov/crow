# Modernization plan: <application or service>

## Scope and gate status

`pending` means a decision or evidence is still required; `approved` means
the named owner authorized the planned work, not that it was executed;
`verified` requires linked results against both builds (and human
confirmation where manual checks apply); `blocked` means work cannot safely
advance. Keep the final row pending until externally held human-run evidence
and owner confirmation are available.

| Phase | Status (pending / approved / blocked / verified) | Owner, date and decision/evidence reference | Open prerequisite |
|---|---|---|---|
| Legacy inventory and process review | pending | | |
| Legacy scenario approval and safe baseline run | pending | | |
| Target architecture, UI decision and stage plan | pending | | |
| Candidate implementation and comparison | pending | | |
| Human-run verification and cutover handoff | pending | | |

Application boundary, owning repository and revision, other involved
repositories and revisions (if any), legacy build ID, candidate build ID,
non-production environment classification, owners, and evidence limits:

## Processes and implemented rules

| Process ID | Trigger / actor | States, decisions and rule IDs | Outcomes, errors and side effects | Source evidence / owner review |
|---|---|---|---|---|
| PROC-001 | | | | |

Link to the canonical `docs/business-rules-data.json` and business-rules
report in their owning repository; do not copy the rule catalogue here.

## External contracts and datastore

| Interface ID | Boundary, owner and consumers | Observable contract / legacy evidence | Comparison method and scenario IDs | Baseline / candidate evidence refs and open gaps |
|---|---|---|---|---|
| IF-001 | | | | |

Document the datastore, schema/stored logic, data formats, startup migrations,
isolation, existing write patterns, and whether old code can read candidate
writes. Link the validated API inventory where applicable. Mark unknown
consumers and untestable contracts explicitly.

## Acceptance and delivery decisions

Link to approved testing scenario documents, automated test location,
`docs/testing/manual-coverage.md` and its feature-owned manual details, and
the legacy and candidate run references. Do not copy manual steps or QA
execution history into this repository. Record the safe reference to
externally held human-run comparison evidence and owner confirmation.

Link to `docs/solution-architecture.md` in its owning repository, official support evidence,
implementation slice plan, approved UI change description or "none",
contract-preservation approach, test isolation, rollback/write-compatibility
proof, and deployment/cutover owner.

| Decision ID | Proposed change or observed difference | Contract impact (must be none) | Owner, date and explicit decision | Scenario or handoff reference |
|---|---|---|---|---|
| DEC-001 | | | | |

## Final comparison and handoff

Record scoped interface/response-case and process/rule counts, scenarios
passed on each pinned build, API gate results if applicable, unresolved
differences, unrun manual checks, environment/evidence gaps, rollback
prerequisites, and the separate authorization needed for production cutover.
Never infer approval from an empty row or claim universal equivalence.
