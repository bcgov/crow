# Testing foundation

Core beliefs that shape every testing decision in this skill. Keep this short; it changes day-to-day
behavior, it isn't a testing philosophy essay.

## Find defects at the earliest stage that can catch them (band-pass filter model)

Prefer this over a rigid pyramid-shape target. Each test level acts as a filter for the defect classes it
can catch cheaply: unit tests catch functional/logic defects, integration tests catch defects that only
appear at a real framework/DB boundary, E2E (out of scope here) catches whole-system defects. Don't try to
catch integration-level defects with a unit test, and don't wait for an E2E test to catch a defect a unit
test could have caught instantly.

**Regression-driven loop (use this whenever a bug is reported):**
1. Reproduce the bug as a *failing* test at the lowest test level that can actually catch it.
2. If it's not reproducible at that level, try the level above and repeat.
3. Simplify the data needed to reproduce it as much as the level allows.
4. Hand off the fix (or apply it), confirm the test now passes, and consider adding one or two nearby tests
   at that same level while you're there.
5. Update the relevant scenario doc / `testing-plan.md` status to reflect the pass.

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
