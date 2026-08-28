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
   framework/external boundary (state machines, combinatorial rules, date math, multi-entity calculations,
   data merge/migration — see that module's scoping criteria).
5. For .NET (`.sln`, `.slnx`, `.csproj`, `.fsproj`, `global.json` present), also load:
   - [`modules/dotnet/unit-tests.md`](modules/dotnet/unit-tests.md) for unit-level work.
   - [`modules/dotnet/integration-tests.md`](modules/dotnet/integration-tests.md) for integration-level work
     against SQL Server.
6. Load a `modules/reference/*.md` file **only** when the core module you're using explicitly points to it
   for the situation at hand (e.g. property-based test generators, the legacy T-SQL harness case, the fuller
   design-smell catalog). Never load a reference file speculatively.
7. Use [`templates/scenario-doc-template.md`](templates/scenario-doc-template.md),
   [`templates/testing-plan-template.md`](templates/testing-plan-template.md), and
   [`templates/testability-notes-template.md`](templates/testability-notes-template.md) when producing the
   corresponding `docs/testing/` artifacts described in the `crow-testing` agent workflow.
8. Add future technology stacks as sibling folders under `modules/dotnet/` (e.g. `modules/node/`,
   `modules/python/`) and route to them here. Never load unrelated technology modules.

## Out of scope

- End-to-end (E2E) / browser UI test automation — not covered yet; a future `modules/e2e/` addition can slot
  into this router without restructuring it.
- Authoring CI/CD pipelines, build/release tasks, or Azure DevOps Server configuration.
