---
name: crow-testing
description: Guide definition and implementation of automated unit and integration tests, including managed updates for copied Crow test-utility templates. Use for a new testing strategy, a feature, bug, pain point, or managed-template drift. End-to-end testing is out of scope for now.
---

# Testing

Use this skill whenever the current task is defining, planning, or implementing automated tests. Do the
homework (repo scan) before opening any discussion. CI/CD pipeline authoring is out of scope; running tests
locally is not.

## Context-efficient loading

1. Load [`modules/workflow.md`](modules/workflow.md) and
   [`modules/foundation.md`](modules/foundation.md) for every engagement.
2. If the repository has no test project yet (or the user wants a fresh discovery pass), load
   [`modules/discovery.md`](modules/discovery.md).
3. Load [`modules/unit-tests.md`](modules/unit-tests.md) when the work is unit-level.
4. Load [`modules/integration-tests.md`](modules/integration-tests.md) when the work crosses a real
   framework/external boundary. The unit-vs-integration decision itself lives in `modules/foundation.md`
   § "Choosing the level" (already loaded per item 1) — apply it before committing to either path. Signals
   that integration *might* be right (state machines, combinatorial rules, date math, multi-entity
   calculations, data merge/migration) are not sufficient on their own; the same logic is often a unit test,
   or should become one by extracting a seam.
5. For .NET (`.sln`, `.slnx`, `.csproj`, `.fsproj`, `global.json` present), also load:
   - [`modules/dotnet/unit-tests.md`](modules/dotnet/unit-tests.md) for unit-level work.
   - [`modules/dotnet/integration-tests.md`](modules/dotnet/integration-tests.md) for integration-level work
     against SQL Server.
6. Load a `modules/reference/*.md` file **only** when the core module you're using explicitly points to it
   for the situation at hand. Available reference material, and its trigger:
   - `property-based-testing.md` — writing a property-based test or its generators.
   - `managed-template-lifecycle.md` — installing a ready-to-copy template, or an existing
     `testing-plan.md` managed-template registry reports drift.
   - `reusable-test-suites.md` — the same field type or contract is tested on three or more models, and
     copying a test file per model is the alternative.
   - `test-data-builders.md` — writing or reviewing a test data builder.
   - `unit-test-types.md` — proposing *what* to test in an area (code-shape-to-test-type catalog). Usually
     loaded once, during discovery or feature scoping.
   - `characterization-tests.md` — the area's current behavior isn't understood well enough to specify;
     legacy code with no coverage.
   - `legacy-seams.md` — you want to test existing code but can't call it in isolation, and refactoring
     first isn't safe because there are no tests yet.
   - `migration-testing.md` — behavior is being *replaced* rather than changed: a rewrite, port,
     re-platform, or a move between stored procedures and application code.
   - `design-smell-catalog.md` — a discovery scan turned up testability problems and the compact list in
     `discovery.md` isn't enough. Loads the triage table only; it links to `design-smell-entries.md` for
     any one entry's full detail.
   - `design-smell-entries.md` — writing up one specific smell found via the catalog's triage table. Loaded
     from `design-smell-catalog.md`, not directly — don't load it just to scan.
   - `testability-improvements.md` — writing up testability findings, or deciding whether a design change is
     worth proposing at all. Pairs with the catalog: that one identifies smells, this one prioritizes and
     justifies the fixes.
   - `language-features-for-testability.md` — reviewing an existing codebase for design migrations that
     newer language/runtime features would enable. Also defines the boundary against SonarQube/Roslyn:
     what the analyzers already report (don't re-derive it) versus what they never will.
   - `legacy-tsql-harness.md` — the logic under test is a stored procedure/function with no EF code path.
   - `integration/harness-selection.md` — starting DB-backed integration work. This is the **entry point**
     for a family of single-decision files (`fixtures.md`, `seeding-and-ids.md`, `cleanup-and-isolation.md`,
     `environment-and-diagnostics.md`); it fans out to whichever sibling matches the decision in front of
     you. Load the siblings one at a time, not as a set.

   Never load a reference file speculatively.

   **Size discipline for future additions:** core modules stay small and answer "what do I do now";
   reference files are single-decision and independently loadable. A reference file that outgrows its one
   decision should be **split**, not allowed to grow.
7. Use [`templates/scenario-doc-template.md`](templates/scenario-doc-template.md),
   [`templates/testing-plan-template.md`](templates/testing-plan-template.md),
   [`templates/testability-notes-template.md`](templates/testability-notes-template.md), and
   [`templates/modernization-handoff-template.md`](templates/modernization-handoff-template.md) when
   producing the corresponding `docs/testing/` artifacts described in `modules/workflow.md`.
   The last one is only for a cross-cutting finding (a habit/convention across many files) or when the user
   asks for a fuller writeup than a `testability-notes.md` row — see
   [`modules/reference/testability-improvements.md`](modules/reference/testability-improvements.md) §
   Handing off.
8. When writing property-based tests in .NET, copy from
   [`templates/dotnet/generators/`](templates/dotnet/generators/) (see
   [`modules/reference/property-based-testing.md`](modules/reference/property-based-testing.md)) through the
   managed-template script rather than regenerating equivalent generator code or copying it without
   provenance.
9. Add future technology stacks as sibling folders under `modules/` (e.g. `modules/node/`,
   `modules/python/`), each with its own `unit-tests.md`/`integration-tests.md` pair mirroring
   `modules/dotnet/`, and route to them here. Never load unrelated technology modules.

## Out of scope

- End-to-end (E2E) / browser UI test automation — not covered yet; a future `modules/e2e/` addition can slot
  into this router without restructuring it.
- Authoring CI/CD pipelines, build/release tasks, or Azure DevOps Server configuration.

## For maintainers of this skill

[`MAINTENANCE.md`](MAINTENANCE.md) is a trigger table for keeping this skill current as C#/.NET (and future
stacks) gain new versions and features. It is written for whoever edits this skill, not for the agent — it
is never loaded during a testing engagement.
