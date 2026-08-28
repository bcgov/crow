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
above isn't enough for the area under review.

## Output of a discovery pass

- `docs/testing/testability-notes.md` — low-hanging fruit, design issues, candidates for testing.
- `docs/testing/testing-plan.md` — the living index (see `templates/testing-plan-template.md`).
- A clear "where should we start" question back to the user, framed around the ranked batches above.
