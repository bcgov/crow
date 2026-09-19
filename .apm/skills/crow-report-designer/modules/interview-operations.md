# Interview operations

Load this module for a live report-design interview or session resume.

## Session and write gates

1. Read existing `design/` artifacts and `design/session-state.md` without
   editing.
2. Ask for explicit repository-write authorization before creating or updating
   session state, draft artifacts, or handoff files.
3. Resume from the last completed phase, unresolved questions, deferred items,
   and confirmed glossary/decision entries. Do not re-ask confirmed answers.
4. Save a new session timestamp and append the prior state; never replace
   confirmed history.

Interview sign-off and repository-write authorization are separate decisions.
If either is missing, keep the result as a draft and do not hand off for
scaffolding or build generation.

## Staleness re-confirmation

On a resumed or long-running session, track `business_requirements` and
`pbirs_version` (not model preferences — Crow does not pin models) as rows
with a user-adjustable cadence in `design/decisions.md` (defaults: 90 and 120
days). When a row is due, ask a brief check-in question before continuing;
update only the stale row's date, or its value and date if it changed. Do not
prompt rows that are not yet due.

## Deferrals and phase gates

Classify each unanswered item as:

- **Blocking**: prevents a reliable grain, security decision, bus matrix,
  source map, or acceptance criterion. The affected phase cannot close.
- **Advisory**: does not prevent the current design decision, but records an
  owner, impact, and due point before implementation or deployment.
- **Unsupported/deferred**: requires a live provider, unavailable evidence, or
  out-of-scope capability. Record the fallback and do not claim verification.

Proceed only when the current phase has confirmed answers or explicitly
classified deferrals. A contradiction reopens the affected phase and any
downstream artifacts that depend on it.

## Grain and source reconciliation

Stress-test each proposed fact grain with at least one counterexample: multiple
events per entity, late corrections, multiple meaningful dates, duplicate
source keys, and period backdating where relevant. Reconcile the result with
the local entity map and source evidence before confirming dimensions or the
bus matrix. Mark a grain provisional when source evidence is incomplete.

Phase 9 refresh/performance capture is defined in
`modules/interview.md`; carry those confirmed values and `architect_notes`
into the signed-off handoff.
