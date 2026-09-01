# Design-smell entries (detail)

Prose detail for each smell in [`design-smell-catalog.md`](design-smell-catalog.md)'s triage table. Load
this file only when writing up **one specific** finding — an agent scanning a codebase needs the triage
table, not all eighteen entries; this file is for the moment a particular smell needs its full explanation.

Each entry is framed the same way `design-smell-catalog.md` frames the whole catalog: the fix moves a
defect class to an earlier, cheaper filter. See that file for the filter-stage framing and the triage table
mapping each entry to its row.

## The entries

- **Nullable-but-required fields.** A nullable property validated as required at every call site is simpler
  as a non-nullable type; the validation (and its tests) disappear entirely.
- **Primitive obsession on constrained values or domain concepts.** A raw `string`/`int`/`decimal` standing
  in for a bounded set of valid values (status codes, roles) *or* for a real domain concept (`Email`,
  `Money`, `OrderNumber`) invites invalid-state bugs and forces re-validation everywhere it's used. A small
  enum/value type validates once at the boundary and is trusted everywhere after, removing a whole class of
  tests.
- **Anemic domain model.** Business rules live entirely in services acting on plain data-bag entities
  instead of on the model itself. Testing a rule then means standing up a service (often integration-
  shaped) rather than exercising a small pure method on the model — pulling logic onto the model turns many
  "integration-flavored" tests into cheap unit tests. See `foundation.md` § "Choosing the level" for how
  this smell causes work to be mis-scoped as integration testing.
- **Hidden static/global state.** Static singletons, ambient `DateTime.Now`/`Guid.NewGuid()` calls inside
  logic, or service-locator patterns make behavior non-deterministic and hard to isolate in a unit test.
- **God methods/classes.** A method doing validation, persistence, and business logic together forces every
  test through all three; splitting responsibilities lets each be tested independently and cheaply.
- **Untestable time/randomness.** Logic that reads the system clock or RNG directly instead of through an
  injectable abstraction can't be tested for edge cases (midnight rollovers, leap years, specific seeds) at
  *any* automated filter — production ends up being the first stage that catches them.
- **Boolean parameter soup.** Methods with several boolean flags controlling behavior are a sign of hidden
  branching that's easy to under-test; consider whether the flags represent a state/strategy that should be
  named explicitly.
- **Missing seams at framework boundaries.** Direct instantiation of `HttpClient`, file I/O, or DB access
  inside business logic (instead of behind an injectable interface) forces every test through the real
  dependency or forces heavy mocking.
- **Boundary enforced only by convention.** A layering rule, dependency direction, or module boundary that
  exists only in a diagram and in reviewers' heads erodes silently — every violation is individually
  reasonable, and six months later everything references everything. Unlike the other entries the fix isn't
  a design change at all: assert the rule as an **architecture test** over the compiled assembly, moving it
  from intermittent human review to a failing build. See
  [`unit-test-types.md`](unit-test-types.md) § architecture tests.
- **Code predating a language feature that would enforce the rule.** A rule defended by hand-written checks
  and their tests, on a project whose target framework has since gained a feature that would defend it at
  compile time — a clock read inline instead of through `TimeProvider`, an `int?` that should be `required`,
  raw identifiers that should be strongly typed. No analyzer reports these; they are design migrations, not
  rule violations, which is exactly why they survive. Retargeting rewrites nothing, so **new code usually
  keeps arriving in the old style** — which makes this a live finding about what the team is still writing,
  not a historical one about code already shipped. See
  [`language-features-for-testability.md`](language-features-for-testability.md) for the ones worth
  proposing, how to check what the project's TFM actually allows, and what to do when a UI or ORM framework
  makes the change impossible.

## DDD / F#-inspired smells (apply equally well to C#)

- **Illegal states representable.** A type allows field combinations that are invalid at runtime (e.g. three
  independent nullable/boolean fields modeling what is really one of four named states). Prefer a smaller
  type — an enum, a discriminated-union-style hierarchy, or a record with a private constructor plus named
  factory methods — so the invalid combination fails to compile or fails to construct, rather than needing a
  runtime check (and a test for that check) everywhere the type is used.
- **Large impure functions mixing decision logic with I/O.** When a method both decides something and
  performs a side effect (DB write, HTTP call, file write) in the same body, the decision logic can't be
  tested without the side effect. Extract the pure decision function and keep the impure shell thin enough
  that it barely needs testing itself — see
  [`testability-improvements.md`](testability-improvements.md) § seam-extraction playbook.
- **Partial functions and silent nulls.** A method whose signature promises a value but can throw or return
  null for some inputs, with nothing in the signature warning callers, forces defensive tests at every call
  site. Prefer a total function (a `TryParse`-style signature or an explicit result/option type) so "no
  valid answer" is an explicit, testable outcome rather than an exception path callers may forget to cover.
- **Long procedural methods.** A long method mixing several responsibilities needs many test cases to cover
  all its internal paths at once. Several small, single-purpose functions can each be covered with a handful
  of focused tests.
- **Mutable state by default.** Settable properties and mutable collections (`List<T>`, `Dictionary<K,V>`)
  let any code path mutate shared state between a test's Arrange and Assert steps, producing order-dependent
  or flaky tests and requiring defensive cloning in setup. Prefer `record` types with `init`-only setters
  and `with`-expressions for copies, and expose `IReadOnlyList<T>`/`ImmutableArray<T>` instead of a mutable
  collection. More fundamentally, immutability doesn't just make that test easier to write: it *eliminates*
  whole bug classes (unintended aliasing, a caller mutating shared state, thread-safety issues from
  concurrent mutation) outright, so there's no bug left for any test to catch.
- **Non-exhaustive branching.** A `switch`/`if-else` chain with a catch-all `default` over an enum or
  union-style type silently swallows a newly added case — existing tests stay green while the new case is
  mishandled at runtime, giving a false sense of coverage. Prefer a `switch` *expression* without a discard
  arm: the compiler warns (`CS8509`) on missing enum members, and with `TreatWarningsAsErrors` (or
  `<WarningsAsErrors>CS8509</WarningsAsErrors>`) that warning becomes a build break — mirroring F#'s
  exhaustive `match`, which most F# projects already build as errors. Recommend enabling that setting
  alongside the fix; without it the warning is visible but not a guarantee. This is the purest filter-zero
  case: a compiler error stands in for the test entirely.
- **Reference equality hiding value differences.** A domain type left as an ordinary class compares by
  reference, so `Assert.Equal(expected, actual)` only passes if both sides are the same object — rarely the
  intent — forcing brittle property-by-property assertions that silently stop covering newly added fields.
  It's also a real production bug class: a hand-rolled or forgotten `Equals` override that omits a field
  exists whether or not a test exercises it. Prefer a `record`/`record struct` for domain value types:
  generated structural equality means one `Assert.Equal` covers every field, including future ones, and
  there's no hand-written override left to get wrong.
- **Exceptions as control flow for expected business outcomes.** Communicating an expected outcome like
  "validation failed" via a thrown exception forces tests into `Assert.Throws<T>` with fragile message-text
  matching, and makes multi-step pipelines hard to test in isolation (the first failure throws, so
  downstream handling can't be exercised independently). This is a broader, pipeline-composition version of
  "Partial functions and silent nulls" above — prefer a `Result<TSuccess, TError>`-style return, chained
  with `Select`/`SelectMany` or `switch` expressions, so each step is independently testable and the whole
  chain is asserted on its final result value, not a caught exception.
