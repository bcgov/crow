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

## What to characterize first

You cannot pin a whole legacy system, and trying is how a testing engagement disappears. Characterize, in
this order:

1. **Code you are about to change.** The net exists to make a specific change safe. If no change is planned,
   the tests have no deadline and no bar for "enough".
2. **Code with a bug history.** Repeat defects in one area mean the behavior is poorly understood by
   everyone, not just you — pinning it pays immediately.
3. **Code blocking a migration or rewrite.** Here the characterization suite becomes the acceptance
   specification for the replacement — see [`migration-testing.md`](migration-testing.md).

**Confirm the code is actually reachable before investing.** Brownfield systems carry a lot of code that is
never invoked — obsolete branches, features switched off years ago, entry points nothing calls. Check call
sites, route registrations, job schedules, and feature flags first. Characterizing dead code is pure waste,
and worse, it makes deleting it harder later.

**Time-box it.** Legacy characterization has no natural end — there is always another input to try. Agree a
budget with the user up front and report what got covered against what didn't, rather than running until
someone stops you.

## The loop

1. **Pick a seam** — a function, method, or entry point you can call without standing up the world. If there
   isn't one, getting one is the first task, and it is usually the hard part: see
   [`legacy-seams.md`](legacy-seams.md) for minimal, behavior-preserving ways to create one, and why the
   clean refactor in `testability-improvements.md` is *not* the right move before tests exist.
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

## Capture what you learn, not just what you pin

Pinning legacy behavior is frequently the only occasion on which undocumented business rules and
terminology surface at all — a threshold nobody could explain, a status that means something different from
its name, an ordering that turns out to be load-bearing. Write these into
`docs/testing/testability-notes.md` (business terminology table) as you find them, and confirm them with
the user.

The tests capture *what* the code does; these notes capture *why*, and they are usually worth more than the
tests to whoever maintains the system next.
