# Testing engagement workflow

Load this module for every Crow testing engagement. It owns the detailed orchestration that would otherwise
bloat the agent.

## Model guidance

Crow agents have no per-agent model pin. Model changes are recommendations, never automatic settings:

- **Lightweight:** implement straightforward tests from approved scenarios with no unresolved behavior.
- **Mid-tier:** synthesize discovery, facilitate the interview-style discussion, draft scenarios, and review
  them at the approval gate.
- **Premium:** use only when a mid-tier pass cannot resolve conflicting or combinatorial business rules.

When practical, use a different model family to spot-check implemented tests against approved scenarios.
Check the Cross-check review log in `docs/testing/testing-plan.md` before implementation and after
verification. If no relevant review exists or it is more than seven days old, suggest a cross-family review;
the user may decline. If the environment cannot switch models easily, record the recommendation and proceed.

## Step 1: Homework

Complete this before opening the discussion:

1. Identify manifests, solution/project files, entry points, target frameworks, and services. In a monorepo,
   inventory each independently and decide whether testing documents belong per service or at the root.
2. Detect test projects, frameworks, assertion and validation libraries, and test-data generation. Distinguish
   a meaningful suite from scaffold/example tests. An effectively empty suite does not lock in its framework.
3. For a meaningful suite, read representative tests, base classes, and infrastructure, fixture, builder, and
   utility helpers. Follow infrastructure decisions while using the style declared by project configuration.
4. Prefer `codebase-memory-mcp` for structural discovery. If unavailable, use repository search/read tools and
   state that analysis coverage may be reduced.
5. Read `README.md`, `docs/`, ADRs, and existing `docs/testing/` artifacts.
6. Record business terms and rules from code and documentation.
7. If testability notes or a modernization handoff exist, compare platform-dependent findings with the current
   TFM and `LangVersion`. Revisit only findings whose recorded rationale depended on an older platform.
8. When shared validation is consumed by multiple model validators, load
   `reference/shared-validator-testing.md` and plan one exhaustive direct suite plus thin wiring/context smoke
   tests for every consumer.
9. When an intended behavior is not covered by automation, load `manual-coverage.md`, classify it before
   proposing a test, and maintain `docs/testing/manual-coverage.md` for manual-only or deferred-automation
   scenarios. A coverage gap remains an automation task.
10. When `docs/testing/testing-plan.md` or existing scenario docs predate the shared Status vocabulary and
   scenario `Coverage` field (no schema marker present), do not rewrite the whole project. Backfill only the
   feature(s) actually being worked on in this engagement; leave other pre-existing rows marked
   `Legacy - pending backfill` rather than assuming their free-text status is current.
11. If `docs/testing/testing-plan.md` contains managed Crow templates, run the managed-template audit. Load
   `reference/managed-template-lifecycle.md` only when installing one or when the audit reports drift.
   Auto-update an unchanged installed copy; stop for a merge/replace/retain decision if the project copy was
   customized. Never regenerate `testing-plan.md` wholesale or discard its managed-template registry.

### Document-maintenance checkpoint

Testing documents are living indexes, not an append-only activity log. Evaluate maintenance when any active
testing document reaches one of these conservative thresholds:

- more than 400 lines;
- more than 25% of its rows are resolved, retired, declined, or otherwise inactive; or
- an inactive item has had no meaningful update for 90 days.

Use repository history or an explicitly recorded authoritative update date to establish the 90-day age.
Do not infer age from QA execution dates, which belong outside repository Markdown.

Use the narrowest affected document as the unit of review. Do not wait for a threshold to remove an item
that is plainly obsolete when the document is already being edited, but do not perform a repository-wide
cleanup pass.

Classify content before pruning:

- **Keep:** current scenario definitions and coverage, authoritative rules, open decisions, active manual or
  deferred coverage, unresolved candidates, and concise context required to understand current behavior.
- **Delete from active documents:** completed or closed work-item draft detail (remove the corresponding
  `testing-plan.md` index row entirely, not just its `Draft path`), resolved or obsolete testability notes,
  retired manual/deferred scenario detail, and completed scenario activity notes that no longer explain
  current coverage. Completed scenario definitions remain when they describe behavior the system still
  supports.
- **Declined candidates:** delete the full draft, but retain one compact `testing-plan.md` index row using
  the exact `Declined / Won't track` status, the subject, `Draft path` set to `None`, and a short reason in
  the row's `Notes` column. This tombstone prevents rediscovery without retaining a large rejected proposal.

Before deleting, verify that the item is not linked from an active scenario, current decision, manual-QA
register, or unresolved work item. If status or ownership is ambiguous, stop and present the affected paths
for user resolution. Record a short maintenance note only when pruning changes how a future agent should
interpret the remaining index; otherwise avoid adding a new history log.

## Step 2: Open the discussion

1. Present discovered facts and concrete assumptions for correction or confirmation.
2. Classify the engagement:
   - broad discovery or no meaningful tests: continue to Step 3;
   - specific feature, bug, or pain point: refresh organization guides if needed, then route to Step 5 or 6.
3. Clarify ambiguous business terminology and write it to `docs/testing/testability-notes.md`; do not leave
   decisions only in chat.
4. Record every recurring manual-only or deferred-automation area in `docs/testing/manual-coverage.md`,
   then create or update its linked detail document under `docs/testing/manual/<feature>/`, using the
   required index/detail fields from `modules/manual-coverage.md`.

## Step 3: Discovery

1. Present stale platform-dependent findings separately before newly ranked candidates.
2. Load `discovery.md`, rank candidates by value, and present manageable batches grouped by feature/module.
3. Record low-hanging fruit and non-blocking testability findings in `docs/testing/testability-notes.md`.
   Include the current TFM and `LangVersion` for platform-dependent findings.
4. Use `modernization-handoff-template.md` for a cross-cutting finding or when the user requests a fuller
   handoff. Suggest a suitable agent or tool by name when helpful, but do not invoke it.
5. Ask which candidate batch to start with.
6. When behavior is unknown and there is no coverage, present a time-boxed characterization plan before code.
   If a seam is required, describe the dependency-breaking technique and its production-code footprint.
7. If discovery surfaces a **confirmed bug** — for example, validation or authorization enforced only in
   UI/client code with no server-side equivalent, per `foundation.md` — or a design smell that directly
   blocks test authoring or requires an explicitly approved seam/refactor, load
   `reference/work-item-drafting.md` and create a draft candidate. Check the local `testing-plan.md`
   Work-item candidates table first. Do not search an
   external tracker. Keep the draft durable until the user confirms manual filing and supplies an ID/link,
   or until a future authorized provider confirms creation. Suspected/unknown behavior stays on the
   characterization path above; ordinary testability/design-smell findings stay in `testability-notes.md` or
   the modernization handoff.

## Step 4: Organization guides

Before a repository's first testing implementation, create or refresh:

- `docs/testing/guides/Unit Test Organization Guide.md`
- `docs/testing/guides/Integration Test Organization Guide.md`

Adapt them to detected conventions. Cover the selected framework/libraries, project and class naming/layout,
builder/test-data patterns, and integration environment and cleanup strategy. Do not regenerate a guide that
is already current.

## Step 5: Integration and complex or critical unit tests

1. Apply `foundation.md`'s level-selection rule. Route boundary-free behavior to Step 6 and propose a seam when
   the boundary is accidental.
2. Load `integration-tests.md` and the applicable technology module.
3. Create `docs/testing/<feature>/<Feature>Scenarios.md` from `scenario-doc-template.md`, including scope,
   terminology, authoritative rules, scenarios, required assertions, and status.
4. Offer to expand partial requirements into a complete scenario set.
5. Stop for explicit user review and approval before writing test code.
6. After approval, implement in phases. Keep the scenario doc's top Current status rollup, Coverage
   field/summary, and `testing-plan.md`'s Feature-scenarios row synchronized as tests land — not just
   reported in chat.
7. Check the cross-family review cadence before implementation and offer a plan review when overdue.
8. When the feature crosses an independently versioned shared/canonical
   dependency, route the conditional contract and resilience guidance in
   `integration-tests.md`; do not expand this into E2E testing.
9. For shared validators, do not duplicate exhaustive rule matrices in consumers; use the routed
   shared-validator two-layer strategy.

## Step 6: Simple unit tests

Load `unit-tests.md` and the applicable technology module. Skip the scenario document and implement once
behavior is clear. Cover success, boundary/edge, and failure paths. Do not add tests that merely restate
trivial pass-through code.

This shortcut (test code + one compact `testing-plan.md` row, no scenario doc or manual-coverage entry)
applies only when **all** of the following hold: behavior is already clear and local; there is no
approval-gated complex/critical scenario; the work does not introduce or change a manual-only/deferred
item; there is no shared-validator exhaustive-matrix obligation; and no meaningful trust/external boundary
is crossed. If any of these don't hold, route to Step 5 instead.

Add or refresh one compact `testing-plan.md` Feature-scenarios row: `Scenarios doc` = `None - simple unit
work`, `Status` = `Automated - <test file or TestClass.Method>`, `Manual/deferred items` = `None`.

## Step 7: Bug regressions

1. Reproduce the bug with a failing test at the lowest level that can detect it.
2. Simplify the reproducing data and verify the fix makes the test pass.
3. Now that the bug is confirmed and reproduced, load `reference/work-item-drafting.md`. Check the local
   `testing-plan.md` Work-item candidates table; if no matching candidate exists, create a durable
   draft under `docs/testing/drafts/` and present it to the user. If the user supplies an existing ID/link,
   reference it. If the user files the presented draft manually, retain the draft until they confirm success
   and provide the ID/link; then update the index and delete the draft. Do not search an external tracker or
   claim an item was created without a verified provider result.
4. Add only nearby tests that protect the same defect class.
5. If behavior is unknown and uncovered, use characterization tests first. Present the characterization
   time-box and any seam technique before making production changes.
6. Update the relevant scenario document and testing plan.

The same Step 6 scope limits apply here: if the regression stays within them, the shortcut is test code +
refreshing the existing `testing-plan.md` row (no new manual-coverage entry). If the fix touches an
approved scenario document, a shared validator, or a trust/external boundary, update that scenario doc's
`Coverage` field/summary too, and add/update the manual-QA index row plus linked detail document only if a
recurring manual-only or deferred item is actually discovered or changed.

## Step 8: Verification

1. Run the existing linter or formatter first, then the smallest relevant test command.
2. For scenario-gated work, compare implemented tests with every approved scenario and required assertion.
3. Confirm all touched tests pass.
4. Persist the transparency signals in the docs themselves, not just the chat response: the scenario doc's
   top Current status rollup and `Coverage` field/summary (when one exists) and `testing-plan.md`'s
   Current status plus Feature-scenarios row (Status, automated coverage, and manual QA scope) must reflect
   this engagement's outcome
   before it is considered complete. Update `manual-coverage.md` only when this engagement actually
   produced or changed a recurring manual-only/deferred item. Update the manual-QA index row and linked
   detail document together. Update the Work-item candidates table and durable draft path whenever a
   confirmed bug or approved actionable design smell is drafted. If the user confirms manual filing, replace
   the draft path with the supplied work-item reference and remove the local draft only after the index update
   succeeds.
5. Confirm manual-only and deferred-automation entries state the QA scope, steps, and expected results in
   the linked detail document; do not report QA execution status in repository docs.
6. Check the cross-family review cadence. If a review is performed, record its date, scope, model family, and
   disposition in `testing-plan.md`.

## Output contract

Report:

- engagement type;
- testing documents created or updated;
- tests changed and the paths, defect classes, or scenario IDs covered;
- non-blocking testability findings and their handoff document;
- what is being tested (feature/behavior, pointing at the scenario doc or `testing-plan.md` row rather than
  restating it), which parts are automated (with test location), and which require manual QA (with the
  `MC-###` scope path, steps, and expected result);
- every confirmed bug or explicitly approved actionable design smell found this engagement, its draft key or
  work-item ID/link, and the current durable draft/index state;
- remaining work;
- exact validation commands and outcomes;
- cross-check review status.
