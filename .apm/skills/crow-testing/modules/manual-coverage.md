# Manual-coverage guidance

Load when a behavior cannot, should not, or will not be covered by the repository's automated tests.

## Required classification

Classify every uncovered behavior as one of the following:

| Classification | Meaning |
|---|---|
| Automated candidate | Existing test infrastructure can cover it and it belongs in automated tests. |
| Manual-only | It depends on rendered UI, browser interaction, environment, timing, concurrency, or another boundary not covered by the repository's automated infrastructure. |
| Deferred automation | It is currently unautomated, but a known infrastructure or design decision is required before automation is appropriate. |
| Coverage gap | Existing infrastructure can test it, but the test has not been added. Add the test; do not relabel it manual-only. |

Do not add a new component-test framework solely for an isolated scenario when the project has explicitly
decided not to add that framework.

## Workflow

1. Inspect the existing test projects, supported test layers, and project decisions before proposing tests.
2. Identify behaviors crossing UI-rendering, browser, database, external-service, timing, or concurrency
   boundaries.
3. Classify each behavior using the table above.
4. Create or update the consuming project's `docs/testing/manual-coverage.md` for every manual-only or
   deferred-automation item.
5. Link each entry to its work item, source component, scenario document, dependency, and recheck trigger.
6. Include manual-only and deferred items in the handoff and completion summary.
7. Revisit entries after refactors, shared-component changes, test-infrastructure changes, or related
   work-item completion.

Manual coverage is not a substitute for an available unit or integration test. Do not claim a feature is
fully tested while manual-only scenarios remain unexecuted.

## Required register fields

Each entry needs a stable scenario ID, work item or feature link, behavior and scope, classification,
reason, prerequisites and test data, manual steps, expected result, evidence to capture, source files or
components, dependencies, recheck trigger, status, and last review date.

Store evidence according to the consuming project's approved security and privacy practices. Redact secrets,
tokens, credentials, personal information, and sensitive request or response data; do not commit evidence
that is not safe for the repository or its release package.

Use `templates/manual-coverage-template.md` for the register shape and individual scenario entries.
