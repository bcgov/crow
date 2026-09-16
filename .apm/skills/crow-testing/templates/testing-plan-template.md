# Testing Plan

<!--
Living index for this repository's automated testing effort.
The current-status rollup comes first for humans and returning agents. Detailed tables remain authoritative.
Status-vocabulary schema: v2.
-->

## Current status

| Field | Current value |
|---|---|
| Overall phase/status | Draft - awaiting decision / Approved - implementation pending / Active / Automated / Partial / Blocked |
| Automated coverage | Count and/or links to tested feature rows |
| Manual QA required | Count and/or `MC-###` references; QA chooses based on release scope |
| Open decisions | Short list or `None` |
| Work-item candidates | Count and/or `DRAFT-*` keys; full drafts are linked below |

<!-- Apply the threshold-triggered document-maintenance checkpoint in modules/workflow.md. -->

<!--
Rollup only. Reconcile these values with the detailed tables below whenever the plan changes. Existing
documents may be backfilled lazily when next touched; do not mass-rewrite older plans.
-->

## Test matrix

| Feature / area | Automated coverage | Manual QA scope | Detail reference | Status |
|---|---|---|---|---|
| | | | | |

## Start here: guides

- `guides/Unit Test Organization Guide.md`
- `guides/Integration Test Organization Guide.md`

## Testability notes

- `testability-notes.md`

## Manual QA scope

- `manual-coverage.md` — index of recurring manual QA areas and release triggers; links to detailed
  scenarios under `manual/`. Execution is tracked outside the repository.

## Work-item candidates

<!--
One row per confirmed bug or explicitly approved actionable design smell. Check this table before creating
a new candidate. Full plain-language drafts live under `docs/testing/drafts/`.
-->

| Draft key | Type | Tracking | Subject | Source | Draft path | Notes |
|---|---|---|---|---|---|---|
| | Bug / Design smell | Draft — not filed / Existing — <ID/link> / Created — <provider>:<ID> / Declined / Won't track | | | | |

<!-- Remove a completed/closed candidate's row entirely once its draft is deleted; do not leave a blanked
row. Keep declined rows as compact anti-rediscovery tombstones: delete the full draft file, set Draft path
to `None`, and record the short decline reason in Notes. -->

## Feature scenarios

<!-- One row per feature or meaningful unit-only work item. -->

| Feature | Scenarios doc | Status | Automated coverage | Manual QA scope | Open decisions |
|---|---|---|---|---|---|
| | | | | | |

## Cross-check review log

| Date | Scope (feature/whole repo) | Reviewing model family | Notes |
|---|---|---|---|
| | | | |

## Managed Crow templates

<!-- Preserve this registry when refreshing the testing plan. -->

| Template ID | Source | Installed path | Namespace | Mode | Source SHA-256 | Installed SHA-256 |
|---|---|---|---|---|---|---|
| | | | | | | |

## Overall notes

<!-- Brief context that cannot be represented by the current-status rollup or detailed tables. -->
