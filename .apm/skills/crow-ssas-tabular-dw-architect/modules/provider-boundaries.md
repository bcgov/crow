# Provider and execution boundaries

## Phase 2 capability register

| Capability | Status | Local fallback |
|---|---|---|
| SQL/SSDT, BIM, and TMDL file inspection | Available | None; ask for files or stop |
| Live SQL Server discovery | Deferred | Local SQL/SSDT or user-provided metadata |
| Live SSAS XMLA/DMV discovery | Deferred | Local BIM/TMDL |
| SQL/DAX/SSIS/pipeline generation as files | Conditional | Present a proposed scaffold for approval |
| Database deployment, SSAS processing, SSIS execution, or ADO execution | Deferred | Plan and validation checklist only |
| Raven/provider authentication and query APIs | Deferred | Do not invent tool names or endpoints |

Before using a deferred capability, require a reviewed provider or execution
contract that identifies the tool/API, authentication boundary, allowed
operations, error behavior, freshness semantics, and confirmation gate. No
such contract is currently packaged for this skill. See
`modules/provider-contract-plan.md` for the planned scope and acceptance
criteria for live SQL/SSAS discovery specifically; this replaces the source
project's live-access paths and is a tracked pre-retirement item, not an
accepted permanent loss.

If live access is unavailable, continue with local evidence when the selected
mode supports it and label row counts, samples, statistics, runtime metadata,
and deployment results as unverified. If the mode has no safe local fallback,
stop with a blocking limitation rather than producing success-shaped output.
