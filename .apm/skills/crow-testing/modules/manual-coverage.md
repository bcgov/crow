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

When an area is retired or equivalent automated coverage is established and passes, remove its detailed
manual scenario document and index row from the active register. Do not retain one-time execution history
in repository Markdown; preserve only a current scenario reference when it is still needed to explain a
coverage decision.

## Selecting a representative sample for a shared UI change

For a UI change to something shared/reused across pages (a layout, design-system control, shared component,
validation pattern), pick one or two representative pages/components instead of enumerating every page.
Prefer the highest-impact sample: highest-traffic or most business-critical, a realistic/maximal data-state
variant, or a permission-sensitive/destructive-action view. If the repository also uses `crow-bcgov-ux`,
reuse its representative-screen categories in
[`review-remediation.md`](../../crow-bcgov-ux/modules/review-remediation.md) instead of restating them here.

Record the sample and reason in the scope section (see "Required register fields" below), and revisit it
only when the shared element or affected pages materially change.

Manual coverage is not a substitute for an available unit or integration test. Do not claim a feature is
fully automated while manual-only, deferred, or coverage-gap scenarios remain. One-time post-fix checks
belong in the work-item draft and should not automatically become recurring `MC-###` scenarios.

## Required register fields

Each index row needs a stable area ID, links, classification, release trigger, and short QA scope. Each
detail document needs a stable scenario ID, links, behavior/scope, classification and reason, and, for
shared UI changes, the representative sample and reason, release/recheck trigger, prerequisites and test
data, the page(s)/relative route(s) a tester navigates to,
manual steps, expected result, and recheck/automation triggers. If the behavior has a UI entry point, record
the actual relative path (for example `/admin/users/{id}/edit`), not just a page name.

Execution evidence — results, screenshots, logs, payloads, run dates — belongs in the team's external QA
system, per the consuming project's security and privacy practices, not in this repository's Markdown.

Use `templates/manual-coverage-template.md` for the index shape and
`templates/manual-scenario-template.md` for each detailed scenario document.
