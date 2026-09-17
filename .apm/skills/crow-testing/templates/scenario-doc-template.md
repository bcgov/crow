# [Feature Name] Scenarios

<!--
Fill in following a plain-language, table-first pattern:
- Keep the current status block first so humans and returning agents can orient quickly.
- Keep the status block as a rollup only; detailed scenario rows below are authoritative.
- This document is living: update it as implementation progresses.
-->

## Current status

| Field | Current value |
|---|---|
| Feature | [Feature name] |
| Phase/status | Draft - awaiting decision / Approved - implementation pending / Automated / Partial - manual/deferred / Partial - coverage gap / Manual-only / Blocked / Legacy - pending backfill |
| Automated coverage | Test paths, classes, or methods; use `None` when not automated |
| Manual QA required | Scenario IDs or `None`; describe recurring QA scope below |
| Open decisions | Short list or `None` |
| Work-item candidates | `None`, `DRAFT-*` key/path, `Existing - <ID/link>`, or `Created - <provider>:<ID>` |

<!--
Rollup only: do not duplicate scenario steps or expected results here. Reconcile these values with the
tables below at every verification pass. Existing documents may be backfilled lazily when this feature is
next touched; do not mass-rewrite older documents.

Maintenance: scenario definitions and current coverage are durable documentation even after their tests
pass. Prune only obsolete scenarios, stale activity notes, or supporting detail that no longer explains
current behavior; never remove a completed scenario merely because implementation is complete.
-->

## Test matrix

| ID | What is tested | Coverage | Test reference / manual QA detail |
|---|---|---|---|
| S1 | | Automated / Manual QA / Deferred / Coverage gap / Not implemented | |

## Scope

<!-- What is being tested, and what is explicitly out of scope. -->

## Terminology

<!-- Any business/domain terms that weren't obvious up front, defined in plain language. -->

## Authoritative rules

<!-- The business rules under test, in plain language. -->

## Scenarios

<!--
Coverage disposition: use the fixed vocabulary below, never free text.
- `Automated - <path/TestClass.Method>` (test exists and passed in this engagement's validation)
- `Partial - manual/deferred: MC-###; automated remainder: <ref>`
- `Manual - MC-###`
- `Deferred - MC-###`
- `Uncovered, automatable - <backlog ref>` (implemented behavior, no test yet)
- `Not implemented - no verification claim`
Split a row when its assertions do not share one unambiguous disposition.

If every scenario shares one disposition, omit the Coverage column and add one summary line naming the exact
scenario-ID range and test location, such as `All S1-S6 automated - FooTests.cs`. Re-evaluate whenever a
scenario is added, removed, or materially changed.
-->

| ID | Operation / setup | Seeded data | Expected result | Additional assertions | Coverage |
|---|---|---|---|---|---|
| S1 | | | | | |

## Required assertions

| Area | Assertion |
|---|---|
| | |

## Conditional external dependency scenarios

Use this table only when the feature has a shared/canonical service, external decision source, event
contract, or digital proof. Omit the table when none applies, and omit individual rows that don't apply
rather than marking them `N/A`.

| Scenario | Required assertion |
|---|---|
| Upstream outage / timeout | No false success; bounded wait and visible recovery or assisted path |
| Stale canonical data | Freshness is represented and stale data is not presented as current |
| Invalid / expired / revoked / replayed proof | Decision is denied or held according to approved behavior |
| Duplicate event | Processing is idempotent and side effects are not duplicated |
| Retry exhaustion / cancellation | Work stops or is queued according to contract and remains observable |
| Fallback / audit | Fallback preserves authorization, assurance, minimization, and available audit/provenance |

## Manual QA scope

<!--
Recurring manual checks only. QA chooses applicable items based on the release. Execution status is tracked
outside the repository. One-time post-fix checks belong in the related work-item draft, not here.
-->

- **Scenario IDs:** `MC-###` or `None`
- **Manual QA detail:** `manual/<feature>/<Feature>ManualScenarios.md`
- **Release trigger:** Every release / when <component or behavior> changes / smoke only

## Related work items

<!-- Point to the testing-plan.md Work-item candidates row and durable draft path; do not duplicate the body. -->

- `None` | `DRAFT-*` | `Existing - <ID/link>` | `Created - <provider>:<ID>`

**Remaining work:** <!-- what's left, in plain language -->

**Unusual decisions:** <!-- anything a future reader would be surprised by, and why -->
