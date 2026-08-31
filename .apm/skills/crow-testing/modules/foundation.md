# Testing foundation

Core beliefs that shape every testing decision in this skill. Keep this short; it changes day-to-day
behavior, it isn't a testing philosophy essay.

## Find defects at the earliest stage that can catch them (band-pass filter model)

Prefer this over a rigid pyramid-shape target. Each test level acts as a filter for the defect classes it
can catch cheaply: unit tests catch functional/logic defects, integration tests catch defects that only
appear at a real framework/DB boundary, E2E (out of scope here) catches whole-system defects. Don't try to
catch integration-level defects with a unit test, and don't wait for an E2E test to catch a defect a unit
test could have caught instantly.

**The compiler and type system are filter stage zero — below unit tests, and the cheapest filter in the
model.** A defect the type system rejects needs no test at all: it can't reach a test run, a review, or
production. So the cheapest possible fix for a defect class is usually a design change that makes the
invalid case fail to compile, not a new test. `reference/design-smell-catalog.md` catalogs the design
choices that push defects *past* the filter that should have caught them, and
`reference/testability-improvements.md` covers what to recommend and in what order.

**Regression-driven loop (use this whenever a bug is reported):**
1. Reproduce the bug as a *failing* test at the lowest test level that can actually catch it.
2. If it's not reproducible at that level, try the level above and repeat.
3. Simplify the data needed to reproduce it as much as the level allows.
4. Hand off the fix (or apply it), confirm the test now passes, and consider adding one or two nearby tests
   at that same level while you're there.
5. Update the relevant scenario doc / `testing-plan.md` status to reflect the pass.

## Choosing the level: the canonical rule

**This is the one authoritative statement of the rule. Other modules point here rather than restating it.**

Ask: **can this behavior be exercised without a real external boundary** (database, HTTP call, file system,
message broker, clock)?

- **No boundary needed → unit test.** Cheap, fast, precise failure messages.
- **Boundary is genuinely intrinsic → integration test.** The behavior *is* the round-trip: persistence,
  query semantics, transactions, triggers, mapping/configuration, wiring.
- **Boundary is an accident of the current design → extract a seam first.** This is the most common and most
  valuable case. Logic often "needs the database" only because rule evaluation was never separated from
  persistence. Pull the decision into a pure function or a method on the domain object, unit test *that*
  exhaustively, and keep one integration test for the round-trip. Raise the extraction as a non-blocking
  testability finding (see `reference/design-smell-catalog.md`, "anemic domain model") rather than accepting
  a slow test as inevitable.

**Tiebreaker when both levels are viable:** choose the lowest level that can actually catch the defect class
— that is the band-pass principle above, applied. A defect that a unit test can catch should not be left to
an integration test.

**When a feature legitimately needs both levels, split the assertions — never duplicate them:**

| Level | Asserts |
|---|---|
| Unit | The business rules and decisions themselves: every branch, boundary, and edge case. |
| Integration | That the decision is correctly *wired and persisted*: one happy path, one representative failure, plus anything only the boundary can break (constraints, concurrency, mapping, transactions). |

Re-asserting the full rule matrix at the integration level is the failure to watch for: it is slow,
redundant, and doubles the maintenance cost of every rule change.

## Not every test should be automated

Some tests need human judgment, exploration, or one-off verification — automating them wastes effort and
adds maintenance burden. Before proposing to automate something, check it is a good candidate: repeatable,
deterministic, cheap to keep passing, and actually valuable to re-run on every change.

## Treat automated test code as a first-class citizen

Test code needs the same design care as production code, because deployment/release decisions increasingly
depend on it. Sloppy, flaky, or unclear tests actively erode trust in the safety net they're supposed to
provide.

## Use UI-level test automation sparingly

Automated UI/E2E testing is compelling to watch and easy to over-invest in (the "law of the instrument").
It has a place, but most functional coverage belongs at the unit or integration level, where feedback is
faster and failures are easier to diagnose.

## Review and prune the suite periodically

Automated tests age. A suite that only grows, never reviewed, ends up bloated, slow, and hard to diagnose —
like a smoke detector nobody checks the batteries on. When touching an area with existing tests, spend a
moment checking whether they still test something real before adding more.

## Sources

- Patrick Prill, "Oh, this stupid pyramid thingy…" (the band-pass filter model, after Noah Sussman)
- SSW Rules to Better Testing (ssw.com.au/rules/rules-to-better-testing) — automation-candidate criteria,
  test-code-as-first-class-citizen, sparing UI automation, periodic test suite review
