# Discovery: no tests exist yet

Use this when a project has little or no automated test coverage and needs a starting point.

## Do the homework first

Before saying anything to the user, scan:
- The tech stack and project structure (manifests, entry points, solution/project files).
- Any existing test project(s), frameworks, and assertion/validation libraries already in use (even if
  nearly empty).
- `README.md`, `docs/`, ADRs, and any existing `docs/testing/` artifacts from a prior engagement.
- Business terminology and rules as they appear in code (domain types, method names) and docs.

Only after this scan, open the discussion **interview-style, surfacing concrete assumptions** grounded in
what was found ("You're using X for validation and have no test project yet — I'll assume unit tests should
follow Y unless you tell me otherwise") rather than asking the user to describe the codebase from scratch.

## Rank candidate testing areas

Favor low-hanging fruit: areas that are easy to test, commonly skipped, and prone to defects. Typical
examples: input validation, boundary/edge-case handling, date/schedule math, permission/role combinations,
and anywhere a bug has already been reported.

To turn an observed piece of code into a concrete proposal — which *kind* of test it calls for and roughly
how many — use [`reference/unit-test-types.md`](reference/unit-test-types.md). It maps code shapes (guard
clauses, mappers, state machines, multiple implementations of one interface, wide outputs) to test types and
techniques, and surfaces cheap high-value work a coverage-driven scan misses.

If an area's current behavior isn't understood well enough to state what it *should* do — common in legacy
code with no tests — propose
[characterization tests](reference/characterization-tests.md) to pin present behavior first, rather than
skipping the area or guessing at a specification.

Present candidates **in batches grouped by feature/module**, not one flat list — this keeps the review
conversation manageable and lets the user redirect early. For each batch, ask which area to start with
rather than assuming.

## Flag testability-improving design issues (non-blocking findings)

While scanning, note design choices that make testing harder than it needs to be — e.g. a nullable field
that's validated as required everywhere it's used, when a non-nullable type would remove the need for that
validation entirely. Record these as **non-blocking findings** for handoff to another agent/developer; do
not block the current testing engagement on fixing them. Write them to `docs/testing/testability-notes.md`
using `templates/testability-notes-template.md`.

For the fuller catalog of design-smell patterns to look for, see
[`reference/design-smell-catalog.md`](reference/design-smell-catalog.md) — load it only if the compact list
above isn't enough for the area under review. Every entry there is framed by which **band-pass filter stage**
the smell pushes a defect past, so the biggest filter jump is the biggest win.

When writing the findings up, use
[`reference/testability-improvements.md`](reference/testability-improvements.md) to prioritize and justify
them — and to decide which ones not to raise at all. A finding that names the cost of leaving the smell in
place gets scheduled; one that only names the smell gets ignored.

## Output of a discovery pass

- `docs/testing/testability-notes.md` — low-hanging fruit, design issues, candidates for testing.
- `docs/testing/testing-plan.md` — the living index (see `templates/testing-plan-template.md`).
- A clear "where should we start" question back to the user, framed around the ranked batches above.
