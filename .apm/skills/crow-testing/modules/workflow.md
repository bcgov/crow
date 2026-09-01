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

## Step 2: Open the discussion

1. Present discovered facts and concrete assumptions for correction or confirmation.
2. Classify the engagement:
   - broad discovery or no meaningful tests: continue to Step 3;
   - specific feature, bug, or pain point: refresh organization guides if needed, then route to Step 5 or 6.
3. Clarify ambiguous business terminology and write it to `docs/testing/testability-notes.md`; do not leave
   decisions only in chat.

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
6. After approval, implement in phases. Keep scenario status and `testing-plan.md` synchronized.
7. Check the cross-family review cadence before implementation and offer a plan review when overdue.
8. When the feature crosses an independently versioned shared/canonical
   dependency, route the conditional contract and resilience guidance in
   `integration-tests.md`; do not expand this into E2E testing.

## Step 6: Simple unit tests

Load `unit-tests.md` and the applicable technology module. Skip the scenario document and implement once
behavior is clear. Cover success, boundary/edge, and failure paths. Do not add tests that merely restate
trivial pass-through code.

## Step 7: Bug regressions

1. Reproduce the bug with a failing test at the lowest level that can detect it.
2. Simplify the reproducing data and verify the fix makes the test pass.
3. Add only nearby tests that protect the same defect class.
4. If behavior is unknown and uncovered, use characterization tests first. Present the characterization
   time-box and any seam technique before making production changes.
5. Update the relevant scenario document and testing plan.

## Step 8: Verification

1. Run the existing linter or formatter first, then the smallest relevant test command.
2. For scenario-gated work, compare implemented tests with every approved scenario and required assertion.
3. Confirm all touched tests pass.
4. Check the cross-family review cadence. If a review is performed, record its date, scope, model family, and
   disposition in `testing-plan.md`.

## Output contract

Report:

- engagement type;
- testing documents created or updated;
- tests changed and the paths, defect classes, or scenario IDs covered;
- non-blocking testability findings and their handoff document;
- remaining work;
- exact validation commands and outcomes;
- cross-check review status.
