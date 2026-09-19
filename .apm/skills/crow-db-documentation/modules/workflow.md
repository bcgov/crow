# Documentation workflow

## Modes and discovery

Start every session with D0 database/schema context, then record the requested
working mode: D1 source database, D2 DW (`Dimension`, `Fact`, `Staging`,
`Internal`, `SSAS`), or D3 SSAS Tabular. If the target is only D0, complete
the context pass and stop at that boundary.
Inspect local SSDT/SQL/TMDL and existing documentation first. Produce a
coverage worklist before drafting. Note unavailable live row counts,
statistics, or metadata explicitly.

Draft descriptions from code evidence and label them `[INFERRED]`. Detect
repeated conventions once, record their scope, affected-object count, and
exceptions, ask for confirmation once, and then batch them. Do not treat a
convention as SQL Server metadata inheritance; expand approved table-level
properties to the affected objects in the generated output.
Apply the Convention-versus-Surprise test: document tables, procedures,
triggers, measures, complex views, non-obvious relationships, and ambiguous
business meaning; skip self-evident fields and system metadata with reasons.
Do not replace existing descriptions without explicit approval.

On a resumed or long-running session, track `business_requirements` staleness
as a row with a user-adjustable cadence (default 90 days) in the target
project's `design/decisions.md`. When due, ask a brief check-in question
before continuing (scope, source systems, or ownership changed?); update only
that row's date, or its value and date if it changed.

## Interview and writes

Present table/model batches with evidence, draft, confidence, and question.
Resolve glossary/decision conflicts explicitly and defer conflicting objects.
For existing artifacts, ask whether to generate a script, edit local files, or
both. Show a diff before editing. New artifacts may use the caller's confirmed
design contract, but still report changes. The inline-by-default behavior for
build-originated artifacts is deferred until a Crow producer agent supplies
that confirmed design contract.

## Local outputs

Use project-local paths when requested: `design/documentation-coverage.md`,
`design/documentation-findings.md`, and `design/documentation-session.md`.
Coverage records source scope, mode, inspected files, skipped/deferred items,
limitations, convention references, affected-object counts, exceptions, and
confirmation status. Findings append each pass's
object/evidence, severity, impact, and disposition; do not replace prior
findings. Session state records decisions, convention confirmations, apply
choice, handoff inputs, and unresolved questions. Preserve prior session
history when resuming or updating these files.

Persist confirmed conventions in the target project's existing
`design/decisions.md` under `## Documentation Conventions` when that register
exists. If it does not exist, record the convention in the session and
coverage outputs and state that cross-session convention reuse is unavailable;
do not create a broader project decisions register without user request.

When resuming, read the prior session, coverage, findings, and decisions
artifacts before inspecting new objects. Preserve prior history, carry forward
unresolved questions and deferred objects, and identify the new pass as a
separate append-only session. If the user pauses or declines a write, record
the stopping point and pending apply choice so the next pass can resume without
re-drafting confirmed work.
