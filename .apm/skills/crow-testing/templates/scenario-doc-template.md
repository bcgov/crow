# [Feature Name] Scenarios

<!-- Living document, table-first: status and test matrix at top, details below. Keep it short. -->

## Current status

| Field | Current value |
|---|---|
| Feature | [Feature name] |
| Phase/status | Draft - awaiting decision / Approved - implementation pending / Automated / Partial - manual/deferred / Partial - coverage gap / Manual-only / Blocked / Legacy - pending backfill |
| Automated coverage | Test files or folders; use `None` when not automated |
| Manual QA required | Manual QA area IDs (`MC-###`) or `None` |
| Open questions | `Q#` IDs or `None` |
| Work-item candidates | `None`, `DRAFT-*` key/path, `Existing - <ID/link>`, or `Created - <provider>:<ID>` |

<!--
Rollup only; the matrix below is authoritative. Reconcile at every verification pass. Do not restructure
older documents to this layout; backfill only when the feature is next touched. Completed scenarios stay
as durable documentation; prune only obsolete rows or notes.
-->

## Test matrix

<!--
One row per example. Group rows by rule and put the simplest first (this is the test list).
Use short sentences, familiar words, and one idea at a time. Put multi-step examples in Example detail
as numbered actions, with one action per step. State the starting situation and expected outcome
separately. Use exact names, amounts, dates, and outcomes. Keep test setup in the test reference.
Every rule has a row, and every row names a rule.

Coverage: `Automated - <test file>` (tests passed in this engagement) /
`Partial - manual/deferred: MC-###; automated remainder: <ref>` /
`Manual - MC-###` / `Deferred - MC-###` / `Uncovered, automatable - <backlog ref>` /
`Not implemented - no verification claim` (behavior not built yet) /
`Fix pending - <draft key or work item> - no verification claim` (reproduced bug in existing behavior,
fix not yet confirmed). Skipped tests do not count as automated. If all rows share one disposition, drop the column and add one
line such as `All S1-S6 automated - FooTests.cs`.
-->

| ID | Rule | Example (plain language) | Expected outcome | Coverage |
|---|---|---|---|---|
| S1 | R1 | Order of $120 with code SAVE10 | Total is $108.00 | |
| S2 | R2 | Order of exactly $100.00 with code SAVE10 | No discount, total $100.00 (pending Q1) | |

## Scope

<!-- One or two lines: what is tested, and what is out of scope. -->

## Rules

<!-- One plain-language business rule per row. Source = code path, document, or stakeholder. If the requester is unsure the behavior is intended, write "Code - not confirmed (Q#)" and add that question below. -->

| ID | Rule | Source |
|---|---|---|
| R1 | Orders over $100 get 10% off | Pricing doc |
| R2 | Orders of exactly $100 get no discount | Code - not confirmed (Q1) |

## Open questions

<!-- Unresolved only; fold answers into a rule or example and delete the row. Omit section if none. -->

| ID | Question | Owner | Blocks |
|---|---|---|---|
| Q1 | Should an order of exactly $100.00 get the discount? Code says no. | Pricing owner | R2, S2 |

## Terms

<!-- Omit if every term is obvious. Define business terms in one line each. -->

## Example detail

<!--
Use only when a calculation, boundary, or disputed outcome needs more than a matrix cell.
Include every relevant boundary and failure case in the matrix or here.
-->

### R# - <rule name> (S#, S#)

- **Starting situation:** <plain-language situation with concrete values>
- **Actions:**
  1. <One action; add one numbered line per action>
- **Expected result:** <what the person sees, with exact values>
- **Boundary cases:** <all relevant nearby cases; omit if none apply>

- **Why it matters:** <one short sentence explaining the rule>

## Prediction mismatches

<!-- Only when a predicted outcome differed from the actual run and the lesson matters later; else omit. -->

| Scenario | Predicted | Actual | What we learned |
|---|---|---|---|

## Cross-cutting checks

<!-- Only checks that apply to several rows (e.g. audit entry written, no sensitive data in logs). Omit if none. -->

| Area | Check |
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

- **Manual QA area IDs:** `MC-###` or `None` (individual runnable checks use `MC-###-##`)
- **Manual QA detail:** Link to runnable checks in the owning feature's `manual/` folder
- **Release trigger:** Every release / when <component or behavior> changes / smoke only

## Related work items

<!-- Point to the testing-plan.md Work-item candidates row and durable draft path; do not duplicate the body. -->

- `None` | `DRAFT-*` | `Existing - <ID/link>` | `Created - <provider>:<ID>`

**Remaining work:** <!-- what's left, in plain language -->

**Unusual decisions:** <!-- anything a future reader would be surprised by, and why -->
