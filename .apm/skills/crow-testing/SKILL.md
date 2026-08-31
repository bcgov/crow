---
name: crow-testing
description: Define, plan, and implement automated unit and integration tests using repository-first discovery and technology-routed guidance. Use for new test strategies, feature coverage, and bug regression tests. End-to-end testing and CI/CD authoring are out of scope.
---

# Crow Testing

Use this skill when defining, planning, or implementing automated tests.

## Context routing

1. Load [`modules/foundation.md`](modules/foundation.md) for every engagement.
2. Load [`modules/discovery.md`](modules/discovery.md) when the repository has no meaningful test suite or the
   user requests a broad testing assessment.
3. Apply the level-selection rule in `foundation.md`, then load:
   - [`modules/unit-tests.md`](modules/unit-tests.md) for unit-level work;
   - [`modules/integration-tests.md`](modules/integration-tests.md) only when behavior crosses an intrinsic
     framework or external boundary.
4. Load technology modules only after detecting the stack:
   - .NET unit tests: [`modules/dotnet/unit-tests.md`](modules/dotnet/unit-tests.md)
   - .NET and SQL Server integration tests:
     [`modules/dotnet/integration-tests.md`](modules/dotnet/integration-tests.md)
5. Load a reference module only when the selected core or technology module links to it for the specific
   decision in front of you. Never inventory or load reference modules speculatively.
6. Use the matching template under [`templates/`](templates/) when the selected workflow produces a scenario
   document, testing plan, testability note, or modernization handoff.

## Engagement workflow

1. Inspect project manifests, target frameworks, existing tests and helpers, repository documentation, and
   prior `docs/testing/` artifacts before opening the discussion.
2. Present discovered facts and concrete assumptions for correction or confirmation. Record clarified
   business terminology in the relevant testing document.
3. For broad discovery, follow `modules/discovery.md`; rank candidates by feature or module and let the user
   select the starting area.
4. For simple unit tests, follow `modules/unit-tests.md` and implement after expected behavior is clear.
5. For every integration area and every complex or critical unit-test area, follow
   `modules/integration-tests.md`: create the scenario document and obtain explicit user approval before
   writing test code.
6. For reported bugs, follow the regression loop in `modules/foundation.md`: first reproduce the bug at the
   lowest effective level, then verify the fix against that failing test.
7. Follow detected project conventions over module defaults. Defaults apply only when no meaningful
   convention exists, and must be presented as overridable recommendations.
8. Run the existing linter or formatter first, then the smallest relevant existing test command. Update the
   testing plan and scenario status to match verified reality.

## Scope and failure behavior

- Unit and integration testing are in scope. Browser/E2E automation and CI/CD pipeline authoring are not.
- Prefer disposable or dedicated integration databases. Treat execution against a shared persistent database
  as a separate decision requiring explicit user approval and a fail-closed server/database allowlist.
- Document testability and modernization issues for handoff; do not change production design unless the user
  explicitly expands the task.
- Stop for unresolved business rules, conflicting authoritative sources, missing required inputs, scenario
  approval, or failed validation. Never convert a failed check into a success-shaped result.

## Maintainers

[`MAINTENANCE.md`](MAINTENANCE.md) maps ecosystem changes to the modules that require review. It is
maintainer-only context and is never loaded during a testing engagement.
