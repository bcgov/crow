# Manual QA scope guidance

Load when a behavior cannot, should not, or will not be covered by the repository's automated tests.
This is a design-time register of recurring QA scope. QA selects applicable scenarios for each release and
tracks execution outside the repository.

## Required classification

Classify every uncovered behavior as one of the following:

| Classification | Meaning |
|---|---|
| Automated candidate | Existing test infrastructure can cover it and it belongs in automated tests. |
| Manual-only | It depends on rendered UI, browser interaction, environment, timing, concurrency, or another boundary not covered by the repository's automated infrastructure. |
| Deferred automation | It is currently unautomated, but a known infrastructure or design decision is required before automation is appropriate. |
| Coverage gap | The behavior is **implemented** and existing infrastructure can test it, but the test has not been added. Add the test; do not relabel it manual-only. |
| Not implemented | The behavior does not exist yet. This is not a coverage gap and makes no automation claim either way; do not register it here until it is built. |

Do not add a new component-test framework solely for an isolated scenario when the project has explicitly
decided not to add that framework.

The scenario doc's `Coverage` field/summary (see `templates/scenario-doc-template.md`) reflects this
classification per scenario ID — link to the `MC-###` entry rather than duplicating its rationale or steps.
Do not record whether QA has executed a scenario in this repository.

## Workflow

1. Inspect the existing test projects, supported test layers, and project decisions before proposing tests.
2. Identify behaviors crossing UI-rendering, browser, database, external-service, timing, or concurrency
   boundaries.
3. Classify each behavior using the table above.
4. Create or update one concise index row in the consuming project's `docs/testing/manual-coverage.md`
   for every recurring manual-only or deferred-automation area.
5. Create or update the linked detail document under
   `docs/testing/manual/<feature>/<Feature>ManualScenarios.md`. Put the detailed test matrix, prerequisites,
   steps, expected results, work item, and recheck/automation triggers there.
6. Include manual-only and deferred items in the handoff and completion summary, clearly stating that the
   register describes QA scope rather than execution results.
7. Revisit entries after refactors, shared-component changes, test-infrastructure changes, or related
   work-item completion.

Manual coverage is not a substitute for an available unit or integration test. Do not claim a feature is
fully automated while manual-only, deferred, or coverage-gap scenarios remain. One-time post-fix checks
belong in the work-item draft and should not automatically become recurring `MC-###` scenarios.

## Required register fields

Each index entry needs a stable area ID, feature or bug link, detail-document link, classification, release
trigger, and short QA scope. Each detail document needs a stable scenario ID, work item or feature link,
behavior and scope, classification, reason, release/recheck trigger, prerequisites and test data, manual
steps, expected result, and recheck/automation triggers.

Execution tracking and run evidence belong in external QA systems according to the consuming project's
security and privacy practices. Do not add execution evidence, screenshots, logs, payloads, or run dates to
the repository's manual-QA Markdown.

Use `templates/manual-coverage-template.md` for the index shape and
`templates/manual-scenario-template.md` for each detailed scenario document.
