# Unit tests (generic)

Stack-agnostic scoping and workflow. Load a `dotnet/unit-tests.md`-style module for stack-specific detail.

## When a unit test is the right tool

**Choosing between unit and integration is decided in [`foundation.md`](foundation.md) § "Choosing the
level"** — the boundary question, the extract-a-seam third branch, the tiebreaker, and how to split
assertions when a feature needs both. Read that first; it is the authoritative rule.

What's local to this module is the *value* filter — given that a unit test is possible, is it worth writing?

**A unit test earns its keep** when the code under test is:
- a **complex transformation or mapping** (multi-step calculations, non-trivial data reshaping),
- **input validation** (cheap to exercise every rule/branch in isolation),
- **boundary/edge-case-heavy logic** (off-by-one-prone ranges, date/time edges, collection edges),
- **policy or decision logic** (rules that pick an outcome from several conditions),
- or **serialization-adjacent logic/custom converters** (custom (de)serialization, formatting, parsing).

**Not every class needs a unit test.** A trivial pass-through, a property getter, or a class with no real
branching adds a low-value test that's expensive to maintain and cheap to skip — prefer covering it (if at
all) through whatever integration/end-to-end path already exercises it.

For *what kinds* of unit tests a given piece of code calls for — a code-shape-to-test-type catalog — see
[`reference/unit-test-types.md`](reference/unit-test-types.md). For code whose current behavior isn't
understood well enough to specify, see
[`reference/characterization-tests.md`](reference/characterization-tests.md).

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
