# Testing a rewrite, port, or re-platform

Load when existing behavior is being replaced rather than changed — a component rewritten, logic moved from
stored procedures into application code (or the reverse), a service re-platformed, or a framework upgrade
large enough that behavior could shift.

## The core move: the old system is the specification

In a modernization effort, characterization tests stop being scaffolding and become the **acceptance
criteria for the replacement**. The sequence:

1. **Pin the old implementation** with characterization tests — see
   [`characterization-tests.md`](characterization-tests.md) for the loop and
   [`legacy-seams.md`](legacy-seams.md) if it can't be called in isolation.
2. **Write the new implementation** against those pinned tests. They are the requirements document nobody
   ever wrote.
3. **Run both against the same inputs and compare.**
4. **Every difference is a decision**, not automatically a defect. See below.
5. **Retire the old path**, and the comparison harness with it.

The value is that it makes an otherwise unfalsifiable claim — *"the rewrite behaves the same"* — into
something a test suite either demonstrates or refutes.

## Branch by abstraction

Put both implementations behind one interface and select between them by configuration. This is what makes
the rest possible:

- Tests can run the **same test body against both implementations** — the contract-test shape in
  [`unit-test-types.md`](unit-test-types.md), applied to old versus new rather than to two peers.
- The switch can be flipped per environment, so the new path can be exercised in a lower environment while
  production stays on the old one.
- Rollback is a configuration change, not a deployment.

Prefer this over a long-lived branch. A parallel branch defers all the integration risk to one moment;
branch-by-abstraction spreads it out and keeps both paths compiling and tested the whole time.

## Shadow runs

Execute both implementations on the same input and diff the results. Two forms:

- **In a test harness.** Feed a corpus of realistic inputs — ideally captured from real traffic or exported
  from production data — through both and assert equivalence. This is the safest form and where to start.
- **In production, read-only.** Run the new implementation alongside the old, discard its output, and log
  differences. Only appropriate when the new path is genuinely side-effect-free; a shadow run that writes
  rows or sends mail is not a shadow run. Watch the added load, and make sure a failure in the shadow path
  can never fail the real one.

Volume matters more than cleverness here. The bugs a rewrite introduces are usually in inputs nobody thought
to include in a hand-written test — odd historical data, nulls that shouldn't exist, encodings, records
predating a schema change. A large captured corpus finds those; twenty hand-written cases don't.

## Normalizing the comparison

A naive equality check drowns real differences in noise. Decide up front which differences are acceptable
and normalize them out **explicitly**, so the exclusion is visible and reviewable:

| Difference | Usual handling |
|---|---|
| Generated identifiers, GUIDs | Exclude from comparison, or map old to new |
| Timestamps, "created on" fields | Exclude, or compare within a tolerance |
| Collection ordering | Sort both sides before comparing, if order genuinely isn't part of the contract |
| Decimal precision / rounding | Compare within a stated tolerance — and confirm the tolerance is acceptable to the business, because rounding differences on money are not cosmetic |
| Whitespace, formatting, culture | Normalize, unless the output is consumed by something that cares |
| Error messages | Compare the error *class* or code, not the text |

Keep the normalizer in one place and treat it as reviewable code. A quietly growing exclusion list is how a
shadow run ends up passing while the rewrite is wrong.

## When they diverge

**The old behavior is the specification until someone decides otherwise.** A divergence is a question for
the user or product owner, not something to resolve by picking whichever result looks more correct.

For each difference, get one of three answers and record it:

- **The new implementation is wrong.** Fix it; the test stands.
- **The old implementation was wrong, and the fix is wanted.** Update the pinned expectation, note it as a
  deliberate behavior change, and make sure it's communicated — an unannounced correctness fix inside a
  migration is still an unannounced behavior change.
- **The old behavior was wrong but must be preserved** — something downstream depends on the quirk. Keep the
  quirk, and record *why*, or the next person will "fix" it.

Record these in the scenario doc or `docs/testing/testability-notes.md`. This list is usually the most
valuable artifact the migration produces: it is the set of undocumented business rules the old system was
enforcing by accident.

## Retiring the old path

Set the exit condition before you start, or the comparison harness becomes permanent: for example, *no
unexplained differences across the full corpus for a stated period, then the old implementation is deleted*.

When you retire it, delete the old implementation, the abstraction that selected between them if it now has
one implementation, and the comparison harness. Then **graduate the characterization tests** into named
specification tests against the new implementation — see `characterization-tests.md` § graduating them.
Leaving the harness in place costs maintenance forever and quietly signals that nobody trusts the migration.
