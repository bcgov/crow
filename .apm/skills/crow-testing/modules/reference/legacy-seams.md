# Getting legacy code under test when there is no seam

Load when you want to test existing code but can't call it in isolation — the logic sits inside a method
that opens a database connection, reads the clock, `new`s up a dependency, or is only reachable through a
framework entry point.

## The chicken-and-egg problem this solves

`testability-improvements.md`'s **seam-extraction playbook** describes the clean refactor: pull the decision
out as a pure function, leave a thin impure shell. That is the right end state — but it is **not safe to
perform on untested code**. You would be restructuring behavior you can't verify.

So there are two different moves, at two different moments:

| | Seam-extraction playbook | This file |
|---|---|---|
| When | After you have tests | Before you have any |
| Goal | The design you'd recommend | The smallest change that lets one test exist |
| Risk appetite | Normal refactor | Near-zero; behavior must be provably unchanged |
| Who does it | Often handed off | Usually you, right now |

Use the techniques here to buy the first test. Once you have a regression net, the playbook applies.

These are Michael Feathers' dependency-breaking techniques (*Working Effectively with Legacy Code*), reduced
to the ones a testing engagement actually reaches for.

## Techniques, cheapest first

- **Sprout method / sprout class.** You need to *add* behavior to an untestable method. Don't edit the body:
  write the new logic as a separate method (or class), fully tested, and call it from one line in the old
  body. The legacy code stays unverified but untouched, and everything new is covered. This is the default
  move when the task is a change rather than a test-writing exercise.
- **Wrap method.** You need new behavior to run *around* existing behavior. Rename the original, then create
  a new method with the old name that calls the renamed original plus your new, tested code. Callers are
  unaffected; the new part is testable in isolation.
- **Extract and override call.** A single awkward call (`DateTime.Now`, a static logger, an email send) sits
  in the middle of otherwise testable logic. Move just that call into its own `protected virtual` method,
  then override it in a test-only subclass. One-line change, no dependency injection, no signature change.
- **Subclass and override.** The dependency is created or resolved in the constructor, so you can't inject
  it. Make the awkward member `virtual`, subclass the type in the test project, and override it. Ugly, and
  deliberately temporary — but it gets the first test written without touching production call sites.
- **Parameterize constructor / parameterize method.** The dependency is `new`ed inline. Add an overload that
  accepts it, and have the existing signature delegate to the new one with the original hard-coded value.
  Nothing that calls it today has to change, and the test calls the new overload.
- **Extract interface.** The proper fix at a framework boundary (HTTP client, file system, repository), and
  the one to prefer when the call sites are few enough that the compiler will find them all for you.

Prefer whichever technique the **compiler can verify**. A signature overload or an extracted interface
produces build errors at every affected site; a behavioral rearrangement does not.

## When nothing at all can be reached: pin from the outside first

Some code has no reachable seam at any cost you'd accept — a request handler that constructs everything it
needs, a batch job driven entirely by configuration. Don't force it. **Start at the outermost boundary you
*can* drive**, get behavior pinned there, and work inward as seams appear:

1. Drive it through the real entrance — an in-process host and real HTTP requests, or a database round-trip.
   See [`integration/harness-selection.md`](integration/harness-selection.md) for the options and their
   costs.
2. Pin the observable results (response, rows written, file produced) as characterization tests. Coarse and
   slow, but real.
3. Now refactor inward under that net, using the techniques above. Each extracted seam gets its own fast
   tests, and the outer characterization tests confirm nothing moved.
4. Delete the coarse tests that the finer ones have made redundant.

This inverts the usual advice to test at the lowest level, and deliberately so: the lowest level isn't
reachable yet. The outer tests are scaffolding, not the destination.

## Use coverage as a targeting tool, not a goal

Before you change anything, run coverage over the characterization tests you've written and look at **which
branches inside the code you're about to modify are actually exercised**. A coverage percentage is not a
goal here; the useful signal is a specific uncovered branch in the path you're about to touch, which tells
you exactly which test to write next.

Two brownfield-specific reads of the same data:

- **An uncovered branch you can't reach with any realistic input** is often dead code. Confirm before
  investing in a test for it — see `characterization-tests.md` § what to characterize first.
- **A branch covered only incidentally** (hit by every test, asserted by none) is not actually pinned. It
  will not fail when you break it.

## Leaving it better than you found it

Every technique above leaves a mark: a `protected virtual` that exists only for tests, a subclass in the
test project, an extra overload. That is an acceptable trade for getting the code under test, but it is not
the end state. Record what you introduced and why in `docs/testing/testability-notes.md`, so the follow-up
refactor is a deliberate, scheduled step rather than something a later reader mistakes for the intended
design.
