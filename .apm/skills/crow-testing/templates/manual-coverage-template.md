# Manual QA index and release scope

<!--
One tester-facing index for recurring Manual-only and Deferred automation checks.
Follow the repository's application/category vocabulary when available; never invent categories or create empty folders.
Link to each application/page-specific check in the owning feature using a plain-language check name;
different rows may link to the same canonical detail document when it contains multiple variants.
Do not copy steps or create a second hand-maintained browse index. Track execution outside
the repository.
-->

## Manual checks

| Application / group or feature | Area ID | Check | Classification | Recheck when |
|---|---|---|---|---|
| [Application / page or feature in user terms] | MC-XXX | [Link to the runnable check with a plain-language action or outcome as its text] | Manual-only / Deferred automation | [When this page or feature changes] |

## Current status

| Field | Current value |
|---|---|
| Index status | Current / Needs backfill |
| Manual QA areas | Count distinct `MC-XXX` area IDs |
| Open decisions | Short list, or omit when none |

## Maintenance

- Keep one row per application/page-specific check link, not per detail document. Repeat an area ID when
  checks span pages or applications, and allow multiple rows to link the same canonical detail document;
  count distinct area IDs, and never reuse a scenario ID for an unrelated behavior.
- Keep the work-item reference in the linked detail; use the index only for navigation and release selection.
- Update the index and detail together when a check's scope, classification, location, or release trigger changes.
- Remove a check only when equivalent automated coverage exists and passes or the behavior is retired.
- QA execution results, build evidence, and run dates belong in the external QA process.
