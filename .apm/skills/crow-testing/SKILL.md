---
name: crow-testing
description: Guide a user through defining and implementing automated unit and integration tests, technology-routed. Use when a project has no tests yet and needs a testing strategy, or when adding tests for a specific feature, bug, or pain point. End-to-end testing is out of scope for now.
---

# Testing

Use this skill whenever the current task is defining, planning, or implementing automated tests. Do the
homework (repo scan) before opening any discussion. CI/CD pipeline authoring is out of scope; running tests
locally is not.

## Context-efficient loading

1. Load [`modules/foundation.md`](modules/foundation.md) for every engagement — it is short by design.
2. If the repository has no test project yet (or the user wants a fresh discovery pass), load
   [`modules/discovery.md`](modules/discovery.md).
3. Load [`modules/unit-tests.md`](modules/unit-tests.md) when the work is unit-level.
4. Load [`modules/integration-tests.md`](modules/integration-tests.md) when the work crosses a real
   framework/external boundary. Signals it might (state machines, combinatorial rules, date math,
   multi-entity calculations, data merge/migration) are not sufficient on their own — apply that module's
   scoping criteria and `modules/unit-tests.md`'s scoping check before committing to this path; the same
   logic is often a unit test if it can be exercised without a real DB/HTTP/external boundary.
5. For .NET (`.sln`, `.slnx`, `.csproj`, `.fsproj`, `global.json` present), also load:
   - [`modules/dotnet/unit-tests.md`](modules/dotnet/unit-tests.md) for unit-level work.
   - [`modules/dotnet/integration-tests.md`](modules/dotnet/integration-tests.md) for integration-level work
     against SQL Server.
6. Load a `modules/reference/*.md` file **only** when the core module you're using explicitly points to it
   for the situation at hand. Available reference material, and its trigger:
   - `property-based-testing.md` — writing a property-based test or its generators.
   - `reusable-test-suites.md` — the same field type or contract is tested on three or more models, and
     copying a test file per model is the alternative.
   - `test-data-builders.md` — writing or reviewing a test data builder.
   - `design-smell-catalog.md` — a discovery scan turned up testability problems and the compact list in
     `discovery.md` isn't enough.
   - `legacy-tsql-harness.md` — the logic under test is a stored procedure/function with no EF code path.

   Never load a reference file speculatively.
7. Use [`templates/scenario-doc-template.md`](templates/scenario-doc-template.md),
   [`templates/testing-plan-template.md`](templates/testing-plan-template.md), and
   [`templates/testability-notes-template.md`](templates/testability-notes-template.md) when producing the
   corresponding `docs/testing/` artifacts described in the `crow-testing` agent workflow.
8. When writing property-based tests in .NET, copy from
   [`templates/dotnet/generators/`](templates/dotnet/generators/) (see
   [`modules/reference/property-based-testing.md`](modules/reference/property-based-testing.md)) rather than
   regenerating equivalent generator code from scratch.
9. Add future technology stacks as sibling folders under `modules/` (e.g. `modules/node/`,
   `modules/python/`), each with its own `unit-tests.md`/`integration-tests.md` pair mirroring
   `modules/dotnet/`, and route to them here. Never load unrelated technology modules.

## Out of scope

- End-to-end (E2E) / browser UI test automation — not covered yet; a future `modules/e2e/` addition can slot
  into this router without restructuring it.
- Authoring CI/CD pipelines, build/release tasks, or Azure DevOps Server configuration.
