# Testability improvements: what to recommend, and in what order

Load when writing up testability findings from a discovery scan, or when deciding whether a design change is
worth proposing. [`design-smell-catalog.md`](design-smell-catalog.md) answers *is this a smell?* — this file
answers *what do I recommend, how do I justify it, and what do I leave alone?*

Everything here produces **non-blocking findings** for `docs/testing/testability-notes.md`, handed off to a
developer or another agent. A testing engagement never stalls waiting for them.

## Shape of a useful recommendation

A finding that just names a smell gets ignored. One that names the *cost of leaving it* gets scheduled.
Give each finding five parts:

| Part | Example |
|---|---|
| Current shape | `ApplicantAge` is `int?`, validated as required in 6 call sites |
| Defect class escaping | A missed null check ships; only caught if a test happens to cover that path |
| Filter it moves to | Unit -> **compiler**; the 6 validations and their tests disappear |
| Rule | nullable analysis / `CA1062` |
| Blast radius | 6 call sites, 1 model, ~40 lines of validation + tests removed |

The "filter it moves to" line is the one that makes the case. Framed as *this defect currently can only be
caught in QA, and this change moves it to compile time*, a change becomes obviously worth doing. Framed as
"primitive obsession", it reads as taste.

## Priority order

Rank findings by these, in order:

1. **How many filter stages the fix moves the defect.** Runtime/production -> compiler is the biggest win
   available; integration -> unit is next; unit -> unit (just fewer or simpler tests) is real but smaller.
2. **Blast radius.** A single seam that unblocks unit testing for a whole module beats a type change that
   improves one class. Prefer fixes whose benefit compounds across future tests, not just today's.
   A **habit** is the largest blast radius there is — its scope is everything written from here on, so a
   convention change ("new code uses the current idiom") normally outranks fixing any individual instance,
   and usually costs less.
3. **Cost and risk of the change.** A type change with compiler-enforced call-site updates is far safer than
   restructuring behavior. Prefer changes where the compiler finds every affected site for you.
4. **Whether the code is already being touched.** A smell inside the feature currently being tested is
   nearly free to fix; the same smell in untouched code costs a separate change, review, and regression
   risk. Say so — it changes the answer.

A finding that scores high on 1 and 2 and low on 3 is the recommendation to lead with. Present at most a few
of those rather than the whole list, or the list gets skimmed and nothing happens.

## The seam-extraction playbook

By far the most common concrete improvement, and the mechanics behind `foundation.md`'s **extract-a-seam**
branch. Use it when logic appears to need a database, HTTP call, clock, or file system only because it was
never separated from one.

1. **Find the decision.** Inside the method, locate the part that decides something — the rule evaluation,
   the calculation, the branch — as distinct from the parts that fetch and persist.
2. **Extract it as a pure function**: all inputs as parameters, result returned, no I/O, no ambient state,
   no clock. It should be callable from a test with nothing but literals.
3. **Leave a thin impure shell**: fetch, call the pure function, persist. The shell should be short enough
   that it barely warrants testing itself, and what it does warrant is one integration test for the
   round-trip rather than the full rule matrix.
4. **Inject what was ambient.** `DateTime.Now` and `Guid.NewGuid()` become a clock/ID abstraction parameter;
   `new HttpClient()` and direct file access become an injected interface.
5. **Move the rule matrix down.** Every branch, boundary, and edge case is now a unit test. Keep one happy
   path and one representative failure at the integration level — see `foundation.md` for the split.

The payoff is measurable and worth stating in the finding: *N slow, DB-dependent tests become N fast ones,
plus 2 integration tests.*

## When not to recommend a change

**The bar: the change must remove more test surface than it adds.** Apply it honestly — a catalog of smells
makes it tempting to propose a rewrite on every engagement, and that costs the agent credibility on the
recommendations that do matter.

Don't recommend a change when:

- **It's an architectural rewrite to make one test easier.** One awkward test is cheaper than restructuring
  a subsystem. Note the awkwardness, write the test, move on.
- **The smell is in stable code nobody is changing.** Untouched code with no bug history isn't paying the
  cost the smell implies. Record it; don't prioritize it.
- **The "fix" only relocates the problem.** Wrapping a static call in an interface that still resolves the
  same singleton adds indirection and changes nothing about what a test can control.
- **You can't name the defect class it prevents.** If the justification is "cleaner" rather than "this class
  of bug becomes impossible / catchable earlier", it isn't a testability finding — leave it out.
- **An analyzer already reports it.** SonarQube and the built-in Roslyn rules run on these projects anyway.
  Re-raising a `CA`/`S`-numbered finding by hand adds noise, not information — it's already on a dashboard
  with a severity. Cite the rule if you happen across the smell; don't go looking for it. See
  [`language-features-for-testability.md`](language-features-for-testability.md) for what tooling covers and
  what it never will.
- **A framework requires the current shape.** Two-way data binding, ORM materialization, and model binding
  impose real constraints. That's a constraint, not a smell — check whether a partial move works (framework
  type at the edge, immutable type in the domain), and if not, record it under "Accepted constraints and
  decisions" in `testability-notes.md` so it isn't re-proposed every engagement.
- **The user has said no.** Record the decision and its reason in `testability-notes.md` so the same
  proposal doesn't resurface next engagement.

## Handing off

Write findings into `docs/testing/testability-notes.md` (see
`templates/testability-notes-template.md`) with the filter stage and priority recorded, so whoever picks
them up inherits the reasoning rather than just the verdict. Mention the highest-priority one or two in the
engagement summary; leave the rest in the document.
