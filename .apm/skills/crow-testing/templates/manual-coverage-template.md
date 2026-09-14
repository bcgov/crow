# Manual QA scope register

<!--
Durable record of recurring manual-only and deferred-automation QA scenarios. Keep one authoritative entry
per scenario and link to it from testing plans and scenario documents.
QA selects applicable scenarios based on the release and records execution outside the repository.
Only manual-only and deferred-automation scenarios belong here; automated candidates and coverage gaps belong
in the automated test worklist. One-time post-fix verification belongs in the related work-item draft.
-->

## Scenarios

### MC-XXX — Short scenario name

- **Work item:** Link or identifier for the item that governs *this specific* manual/deferred scenario only.
  If none exists yet, use the draft-only work-item flow in
  `modules/reference/work-item-drafting.md` and record its local key/status here rather than leaving this
  blank. Do not use this field for an unrelated incidental issue; that belongs in `testing-plan.md`'s
  "Work-item candidates" table.
- **Classification:** Manual-only | Deferred automation
- **Scope:** What behavior is covered and what is excluded.
- **Reason:** Why the repository's automated tests do not cover this behavior.
- **Release trigger:** Every release | When <component or behavior> changes | Smoke only
- **Prerequisites:** Environment, account/role, records, feature flags, and data setup.
- **Steps:**
  1. ...
  2. ...
- **Expected result:** ...
- **Evidence:** Screenshot, recording, request/response, log, or other durable evidence.
- **Source:** Files, components, or scenario documents.
- **Dependencies:** Work items, services, or infrastructure.
- **Recheck trigger:** Changes that require this scenario to be repeated.

## Maintenance

- Keep one authoritative entry per recurring manual scenario; link rather than duplicate steps.
- Change the classification when infrastructure or design changes.
- Close or remove an entry only when equivalent automated coverage exists and passes, or the behavior is
  retired.
- QA execution results, build evidence, and run dates belong in the team's external test process.
