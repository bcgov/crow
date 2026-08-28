# Unit tests (generic)

Stack-agnostic scoping and workflow. Load a `dotnet/unit-tests.md`-style module for stack-specific detail.

## When a unit test is the right tool

Unit tests are for behavior that can be exercised without a real framework/external boundary: pure logic,
validation rules, calculations, mapping, state transitions confined to a single class/module. If correctness
depends on a real database, HTTP pipeline, or other external system, see `integration-tests.md` instead.

## Workflow

1. Confirm the behavior and its success/failure/edge cases with the user if not already clear from the
   discussion or discovery pass.
2. Prefer simple/CRUD cases: go straight from discussion to writing the tests — no scenario document needed.
3. For **complex or critical** unit-test areas (e.g. combinatorial validation rules, business-critical
   calculations), use the same scenario-doc-first workflow as integration tests
   (`integration-tests.md` § Scenario-doc-first workflow) before writing code — this is a hard gate, not
   optional for that case.
4. Cover success, boundary/edge, and failure paths. Use a builder pattern for constructing test subjects
   when a type has many fields, so each test only sets what it cares about.
5. Prefer property-based tests (when the stack supports them) for validation rules and invariants with many
   input combinations, alongside a handful of concrete example tests for readability.
6. Run the smallest relevant test command after writing/changing tests, not the full suite, unless the
   change is broad.
