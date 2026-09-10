# Design-smell entries (detail)

Prose detail for each smell in [`design-smell-catalog.md`](design-smell-catalog.md)'s triage table. Load
this file only when writing up **one specific** finding — an agent scanning a codebase needs the triage
table, not all twenty-two entries; this file is for the moment a particular smell needs its full
explanation.

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
- **Same decision axis branched-on repeatedly across methods/classes.** A switch/if-else keyed on the same
  type code or enum (order type, worker role, notification channel) appears again in a second, third method
  — not the identical branch bodies Sonar's duplication/`S1871` already catches, but the *same choice* being
  made independently each time. A new case means finding and updating every copy, and a copy that's missed
  keeps compiling and stays green, because nothing connects the copies to each other. Extracting one Strategy
  per case (a shared interface, or a `Dictionary<TKey, Func<...>>` for a genuinely open/runtime-extensible
  set) means each case is tested once, in isolation, and adding one adds one new case + one new test,
  untouched by the rest. Prefer an exhaustive `switch` *expression* over a closed enum instead (see
  "Non-exhaustive branching" above) when the set of cases is fixed — it keeps the compiler's exhaustiveness
  check, which `Dictionary<TKey, Func<...>>` gives up. Reach for class-based Strategy over the dictionary
  form when a case carries its own state, dependencies, or needs DI resolution. Not every repeated switch
  is this smell — two call sites, or a set that never grows, may not be worth the indirection; the finding is
  about *drift risk on change*, not switch statements in general.
- **Cross-cutting concern inlined in business logic.** Retry loops, caching, telemetry, or auth checks
  written directly inside a method that also contains the actual business rule force every test of the rule
  to also arrange or mock the concern — a bug in the retry logic and a bug in the rule surface as the same
  kind of test failure, and it's not obvious which broke. No analyzer suggests extracting the concern;
  cognitive-complexity rules (`S3776`) only fire once the resulting method is already large, and never point
  at *why*. Extracting a decorator behind the existing interface lets the core rule's tests stay ignorant of
  the concern; the decorator itself only needs one test for the concern's own behavior (a retry actually
  retries, a cache actually caches) — not a full re-test of the rule it wraps. Check first whether the
  framework already provides this before hand-rolling one: ASP.NET Core middleware *is* Decorator for HTTP
  pipelines, Polly supplies retry/circuit-breaker wrappers, and Scrutor adds decorator registration to
  `Microsoft.Extensions.DependencyInjection`. This fits boundary-oriented, wrapper-shaped concerns
  (retry/caching/telemetry/resilience) best; logging is often too cheap to be worth it, and authorization
  frequently belongs in a framework policy or is inseparable from the business rule itself — judge those concerns
  case by case rather than extracting on reflex.
- **Same boolean business rule re-expressed inline in multiple syntactic forms.** A rule like "is this order
  eligible for expedited shipping" appears as a LINQ `.Where(...)` predicate in one place and an `if` in
  another — the same logic, but no analyzer flags it because the two copies aren't token-identical (Sonar's
  copy-paste detection only catches literal/near-literal duplication, not the same rule expressed
  differently). Each copy needs its own test, and the copies silently drift: a rule change updates one copy,
  its test still passes, and the untouched copy becomes a latent bug that only a missed call site reveals.
  A single named predicate (a method, or a small Specification-style object) tested once and called
  everywhere the rule applies removes that drift outright. Reach for a full composable Specification
  (`And`/`Or`/`Not`, or an `Expression<Func<T,bool>>` for translation into an EF/`IQueryable` provider) only
  when the predicates are actually combined at runtime or need to run inside a query — for a handful of
  plain call sites, a single static method is the same testability win without the extra machinery. Note a
  plain `bool` method and `Expression<Func<T,bool>>` are *not* interchangeable when the predicate must be
  translated by a LINQ provider rather than evaluated in memory.
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
- **Error-prone or ambiguous construction.** A constructor (or factory function) with many parameters —
  especially several of the same primitive type — invites positional-argument mixups that still compile and
  can pass silently unless a test specifically probes for that swap. Related but distinct symptoms: required
  vs. optional properties aren't distinguished in the signature; the object has several genuinely valid
  "shapes" depending on a mode, forcing overloaded constructors or nullable fields that are only sometimes
  required; or an invariant spans several properties together and can't be checked until all of them are
  set, so a partially-built object is briefly (or permanently, if a caller forgets a step) invalid. Every
  valid/invalid combination needs its own construction-path test under this shape, and a swapped same-typed
  argument is a defect class ordinary code review is bad at catching.

  The right fix depends on which of those shapes is present — don't reach for the same pattern every time:
  - **Static factory method(s) + private constructor** — a few clearly named valid configurations exist
    (`Order.CreateStandard(...)`, `Order.CreateExpedited(...)`). Cheapest fix, no new type, and each factory
    can enforce its own invariant before returning.
  - **Builder pattern** — a genuine mix of required and optional properties, or valid combinations too
    numerous/varied to reduce to a small set of named factories, especially where construction is naturally
    incremental (fluent/staged) and validation should happen once, at a single `Build()`/`Create()` call.
  - **Factory Method / Abstract Factory** — the *type* to construct varies by context (polymorphic
    creation), not just its parameter values.

  This is a **production-code** recommendation and is distinct from
  [`test-data-builders.md`](test-data-builders.md), which covers builders written to construct *test
  subjects* — the two are easy to conflate since both are called "builders," but one is an API-design fix
  shipped in the domain, the other is test infrastructure that never ships. Recommending one doesn't imply
  the other is unnecessary or redundant.
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
