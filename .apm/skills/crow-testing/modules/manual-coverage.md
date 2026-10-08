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
4. Create or update the consuming project's single `docs/testing/manual-coverage.md` browse/release
   index using `templates/manual-coverage-template.md`, adapted to the repository's vocabulary and
   existing rows. Use one row per linked manual detail document, repeating the area ID for checks in
   different pages or applications. Show the stable area ID, linked detail, classification, and release
   trigger. Do not maintain a second hand-written browse index or copy steps into the register.
5. Create or update linked detail in the owning feature's `manual/` folder. Follow the repository's
   `docs/testing/guides/scenario-organization.md` when present, including group, cross-application,
   and first-use ownership decisions. Otherwise follow the existing project layout, or use
   `docs/testing/scenarios/<application>/<feature>/manual/` when the application is known and no
   approved group applies (`docs/testing/scenarios/<feature>/manual/` only when no application boundary
   applies). Resolve applicable pending ownership before creating new detail. Prefer the repository's manual template
   when available, otherwise use `templates/manual-scenario-template.md`. Put reproducible
   prerequisites, user actions and observable expected results first; place the route, work item, source
   components, classification rationale and known gaps under Technical details. For UI checks, give
   testers the visible menu path, on-screen control labels, and recognizable test data in everyday
   language rather than code navigation or backend instructions.
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

Record the sample and reason under "Representative pages" in the detail document's Technical details,
and revisit it only when the shared element or affected pages materially change.

Manual coverage is not a substitute for an available unit or integration test. Do not claim a feature is
fully automated while manual-only, deferred, or coverage-gap scenarios remain. One-time post-fix checks
belong in the work-item draft and should not automatically become recurring `MC-###` scenarios.

## Required register fields

Only `Manual-only` and `Deferred automation` behaviors belong in this recurring register.

- **Automated candidate:** record it in `docs/testing/testability-notes.md` during discovery. Once the
  user selects it for implementation, add or update the corresponding `testing-plan.md` test-matrix or
  feature row and implement it at the appropriate test level.
- **Coverage gap:** record it in the relevant scenario document's `Coverage` field as
  `Uncovered, automatable - <backlog ref>` and in `testing-plan.md` until the test is added and passes.
  Do not create an `MC-###` manual-QA entry.
- **Not implemented:** do not make a coverage claim or create a manual-QA entry until the behavior exists.

Each index row needs an application/category or feature grouping where known, a stable area ID (`MC-XXX`),
a descriptive link to the runnable detail, classification (per row or shared when uniform), and a
release/recheck trigger. Keep the work-item reference in the linked detail; existing indexes with a
work-item column may retain it. Each detail document needs that stable area ID plus stable scenario IDs
(`MC-XXX-01`, `MC-XXX-02`, ...), related work item, behavior/scope, classification and reason, status
when draft or unresolved, release/recheck trigger, required role or permissions, starting page, exact test
data state (including status, dates, or relationships when relevant), setup owner if the tester cannot
prepare it, external dependencies when relevant, manual steps, and expected results. For a UI entry
point, put the user-facing navigation at the top and the actual relative route (for example
`/admin/users/{id}/edit`) under Technical details.

Do not assign the same scenario ID to unrelated checks in different documents. If one scenario spans
pages/applications, label each variant with its page/application and expected result, and keep its area ID
stable; give independent checks distinct scenario IDs. Do not invent a future date, persistence assertion,
or other precondition absent from approved behavior.
For a short check, omit the duplicate scenario matrix; use a compact actions/results table only when
multiple independent one-action checks share the same setup. Give multi-step or differently prepared
checks their own numbered steps, expected result, and setup. Describe each UI action using verified
on-screen labels, exact values when needed, and an outcome the tester can observe; ask for clarification
when labels or behavior cannot be confirmed. Do not ask a tester to call an API, query a database, read
source code, or infer a result from logs; if setup requires technical help, name its owner. Keep technical
rationale out of the tester's starting path, but retain required traceability and gaps at the bottom.
An automated rule test does not prove rendered UI behavior.
Reference automated coverage by test file or folder, not a method name; a location is evidence to inspect,
not proof of passing coverage.

Execution evidence — results, screenshots, logs, payloads, run dates — belongs in the team's external QA
system, per the consuming project's security and privacy practices, not in this repository's Markdown.

Use the repository's manual template where provided; otherwise use Crow's tester-first manual scenario
template and single browse/release index.
