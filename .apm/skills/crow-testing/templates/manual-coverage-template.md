# Manual coverage register

<!--
Durable record for manual-only and deferred-automation scenarios. Keep one authoritative entry per
scenario and link to it from testing plans and completion summaries.
Only manual-only and deferred-automation scenarios belong in this register; automated candidates and coverage
gaps belong in the automated test worklist.
-->

## Scenarios

### MC-XXX — Short scenario name

- **Work item:** Link or identifier
- **Classification:** Manual-only | Deferred automation
- **Status:** Planned | Ready | Executed | Blocked
- **Scope:** What behavior is covered and what is excluded.
- **Reason:** Why the repository's automated tests do not cover this behavior.
- **Prerequisites:** Environment, account/role, records, feature flags, and data setup.
- **Steps:**
  1. ...
  2. ...
- **Expected result:** ...
- **Evidence:** Screenshot, recording, request/response, log, or other durable evidence.
- **Source:** Files, components, or scenario documents.
- **Dependencies:** Work items, services, or infrastructure.
- **Recheck trigger:** Changes that require this scenario to be repeated.
- **Last reviewed:** YYYY-MM-DD

## Maintenance

- Keep one authoritative entry per manual scenario; link rather than duplicate steps.
- Change the classification when infrastructure or design changes.
- Close or remove an entry only when equivalent automated coverage exists and passes, or the behavior is
  retired.
- Preserve the reason for manual coverage and historical evidence when updating an entry.
