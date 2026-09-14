# Manual QA scope index

<!--
Single index for recurring manual-only and deferred-automation QA scope.
Keep this document concise. Put setup, steps, and expected results in linked detail
documents under docs/testing/manual/<feature>/.
QA selects applicable rows based on the release and records execution outside the repository.
-->

## Current status

| Field | Current value |
|---|---|
| Index status | Current / Needs backfill |
| Manual QA areas | Count and/or links below |
| Open decisions | Short list or `None` |

## Manual QA areas

| Area ID | Feature / bug | Detail document | Classification | Release trigger | QA scope summary |
|---|---|---|---|---|---|
| MC-XXX | | `manual/<feature>/<Feature>ManualScenarios.md` | Manual-only / Deferred automation | Every release / When changed / Smoke only | |

## Maintenance

- Keep one index row per recurring manual-QA area.
- Link to a detail document instead of copying steps into this index.
- Update the row and detail document together when scope, classification, or release trigger changes.
- Close or remove an area only when equivalent automated coverage exists and passes, or the behavior is retired.
- QA execution results, build evidence, and run dates belong in the team's external test process.
