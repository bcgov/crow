# Characterization tests

Load when the code under test has no coverage and its current behavior isn't well enough understood to write
a specification test — typically legacy code nobody wants to touch, or a bug report in an area with no tests.

## What they are

A characterization test asserts **what the code does today**, not what it should do. You write it by running
the code, observing the output, and pinning that output as the expected value. It is deliberately not a
statement of correctness.

The point is leverage: you can't safely change code whose behavior you can't observe, and you can't write a
specification test for behavior nobody can specify. Characterization tests break that deadlock by giving you
a regression net *first*, so the refactor or fix that follows is verifiable.

## The loop

1. **Pick a seam** — a function, method, or entry point you can call without standing up the world. If there
   isn't one, extracting one is the first task (see `design-smell-catalog.md`).
2. **Call it and record the output.** Start with realistic inputs, then widen: empty, null, boundary,
   malformed.
3. **Pin the observed output as the assertion.** For wide or structured output, use approval/snapshot
   testing rather than dozens of hand-written assertions.
4. **Repeat until the behavior stops surprising you.** Coverage of the branches you intend to change is the
   bar — not total coverage.
5. **Then change the code.** Any test that now fails is a behavior change; decide deliberately whether it
   was intended.

## When the current behavior is obviously wrong

**Record it; don't silently "fix" it.** Pin the wrong behavior with a clear marker — a test name that says
so (`Discount_CurrentlyRoundsDown_KnownIssue`), a comment stating what's expected instead, and an entry in
`docs/testing/testability-notes.md`.

Two reasons this matters:

- Something downstream may already depend on the quirk. Changing it inside a "just adding tests" task turns
  a safe change into an unannounced behavior change.
- Correctness is a decision for the user or product owner, not for whoever happened to be adding tests.
  Surface it, get a decision, then change behavior and test in the same deliberate step.

## When to stop

Stop when you can predict the output before running the test. That's the signal you understand the code well
enough to move on — continuing past it produces tests that pin incidental detail and break on every harmless
refactor.

Be alert to over-pinning: a characterization test that asserts exact formatting, ordering, or internal
structure that nobody actually depends on will fight every future change. Pin the behavior that matters.

## Graduating them into real tests

Once behavior is understood and confirmed with the user, rewrite characterization tests as specification
tests: rename them for the rule they express, replace pinned literals with intent-revealing expectations,
and delete the ones that only pinned incidental output. The scaffolding has done its job — leaving it in
place indefinitely leaves a suite that documents accidents rather than requirements.

Record in the scenario doc or `testing-plan.md` which tests are still characterization-stage, so nobody
mistakes a pinned quirk for an agreed requirement.
