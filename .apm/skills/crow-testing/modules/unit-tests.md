# Unit tests (generic)

Stack-agnostic scoping and workflow. Load a `dotnet/unit-tests.md`-style module for stack-specific detail.

## When a unit test is the right tool

Unit tests are for behavior that can be exercised without a real framework/external boundary: pure logic,
validation rules, calculations, mapping, state transitions confined to a single class/module. If correctness
depends on a real database, HTTP pipeline, or other external system, see `integration-tests.md` instead.

**Scoping check (use this before scoping something as integration work, too):** can the behavior be
exercised without a real external boundary? If yes, it's a unit test even if it came up during an
integration-flavored conversation — don't let it drift into a scenario doc/DB-backed test by default. An
**anemic domain model** (business rules living entirely in services over plain data-bag entities) is a
common reason logic that could be a cheap unit test ends up looking integration-shaped instead; see
`reference/design-smell-catalog.md`.

**A unit test earns its keep** when the code under test is:
- a **complex transformation or mapping** (multi-step calculations, non-trivial data reshaping),
- **input validation** (cheap to exercise every rule/branch in isolation),
- **boundary/edge-case-heavy logic** (off-by-one-prone ranges, date/time edges, collection edges),
- **policy or decision logic** (rules that pick an outcome from several conditions),
- or **serialization-adjacent logic/custom converters** (custom (de)serialization, formatting, parsing).

**Not every class needs a unit test.** A trivial pass-through, a property getter, or a class with no real
branching adds a low-value test that's expensive to maintain and cheap to skip — prefer covering it (if at
all) through whatever integration/end-to-end path already exercises it.

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
