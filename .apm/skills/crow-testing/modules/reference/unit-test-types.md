# Unit test types: from code shape to test proposal

Load when proposing *what* to test in an area — typically once, during discovery or when scoping a feature.
This is the catalog behind `unit-tests.md`'s value filter: that module says whether a unit test is worth
writing, this one says which kind to write and how.

Use it as a lookup: find the shape you actually observed in the code, then propose the matching tests.

| Code shape you found | Test type to propose | Technique that suits it |
|---|---|---|
| Pure calculation / transformation | Example tests for known inputs; invariants over the input space | Example + property-based |
| Input validation rules | One test per rule, plus the accept/reject boundary of each | Parameterized + property-based |
| Guard clauses / argument checks | Error-path tests: each guard throws/returns the right failure for the right input | Parameterized |
| Boundary-heavy logic (ranges, dates, collections) | N-1 / N / N+1 at every boundary; empty, single, many | Example + property-based |
| State machine / lifecycle | Legal transitions succeed; **illegal transitions are rejected** | Parameterized over the transition matrix |
| Mapper / DTO projection | Round-trip: map out, map back, compare; plus every field is actually carried | Property-based (round-trip is a natural invariant) |
| Policy / decision logic | One test per outcome, plus precedence when several conditions match | Parameterized |
| Serializer / custom converter | Round-trip; malformed input; culture/locale sensitivity | Property-based + example |
| Several implementations of one interface | **Contract tests**: one suite run against every implementation | Shared abstract suite (see [`reusable-test-suites.md`](reusable-test-suites.md)) |
| Operation expected to be safe to repeat | **Idempotency**: applying twice equals applying once | Example + property-based |
| Order-independent operation (merges, sets, aggregation) | **Commutativity/ordering**: shuffled input yields the same result | Property-based |
| Large or structured output (reports, generated documents, formatted text) | **Approval/snapshot**: compare against a reviewed baseline | Approval |
| A structural rule people are asked to follow in review (layering, dependency direction, naming, no cross-feature references) | **Architecture tests**: assert the rule over compiled types | Reflection-based assertion library |
| Code whose current behavior is not understood | **Characterization tests** — see [`characterization-tests.md`](characterization-tests.md) | Approval + example |

## Notes on the less obvious entries

**Error paths are under-tested almost everywhere.** The happy path gets written because it's the reason the
code exists; the guard clauses get written and never exercised. They're cheap to test and they're what
actually runs when something upstream goes wrong.

**Illegal transitions matter more than legal ones.** A state machine test suite that only proves the valid
path works will pass just as happily when a guard is deleted. Assert the rejections.

**Round-trip is the highest-value property available for free.** Any pair of inverse operations —
serialize/deserialize, map/unmap, encode/decode, save/load — gives you a property with no oracle needed:
`f(g(x)) == x`. Propose it wherever such a pair exists.

**Contract tests are a *type* of test, not just a reuse mechanism.** When an interface has more than one
implementation (a real one and a fake, two storage backends, a cached and uncached variant), the interface
has a contract that every implementation must satisfy. Write it once, run it against all of them; new
implementations then inherit the whole suite. This is the single highest-leverage test type most projects
never propose.

**Idempotency and ordering are the properties behind most "it worked in dev" bugs.** Retries, at-least-once
message delivery, and re-run imports all assume idempotency that nothing verifies.

**Approval testing earns its place for wide outputs**, where writing dozens of field assertions is tedious
and unreadable. The trade-off: a reviewed baseline is only as good as the review, and a careless "approve
all" silently blesses a regression. Use it where the output is genuinely large, and read the diff.

**Architecture tests move a whole defect class down a filter stage.** Rules like "the domain must not
reference infrastructure", "no feature folder may reference another", "handlers must be sealed", or
"everything in this namespace ends in `Validator`" are normally enforced by human code review — which is to
say, enforced intermittently. A reflection-based test over the compiled assembly turns each one into a
failing build. In `foundation.md`'s terms this is close to filter stage zero: the erosion is caught at build
time by a rule, not by whoever happens to review the pull request.

They apply to any codebase with a structural rule worth keeping — layered, modular, or feature-sliced — and
are cheap: a handful of tests covering the rules the team already argues about in review. Propose them when
you see a boundary that exists only by convention, especially one that has already been violated somewhere.
Keep them few and name them after the rule, so a failure reads as "this rule was broken" rather than "some
architecture test failed".

## How to use this during discovery

For each candidate area you rank, name the shape, the test type, and roughly how many tests it implies. That
turns "we should test the pricing module" into something a user can actually approve or reject — and it
surfaces cheap high-value work (guard clauses, round-trips, contracts) that a coverage-driven scan misses.
