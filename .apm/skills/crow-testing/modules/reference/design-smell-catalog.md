# Design-smell catalog (testability)

Deeper catalog of design choices that make testing unnecessarily hard. Use during `discovery.md` scans when
the compact list there isn't enough. Each item is a candidate non-blocking finding for
`docs/testing/testability-notes.md` — flag, don't fix, unless asked. Every entry ties to testing through at
least one of two lenses: **(a)** it makes tests harder to write or isolate, or **(b)** it increases the
*number* of tests needed because correctness isn't enforced by construction (e.g. immutability doesn't just
make a test easier to write — it eliminates the bug class the test would have existed to catch). Where a
real SonarQube/Microsoft rule exists, it's noted for stronger justification when handing off; where none
exists, that's stated plainly rather than invented.

- **Nullable-but-required fields.** A nullable property validated as required at every call site is simpler
  as a non-nullable type; the validation (and its tests) disappear entirely. (No single canonical rule ID;
  covered indirectly by nullable-reference-type analysis and `CA1062` — validate arguments of public
  methods.)
- **Primitive obsession on constrained values or domain concepts.** A raw `string`/`int`/`decimal` standing
  in for a bounded set of valid values (status codes, roles) *or* for a real domain concept (`Email`,
  `Money`, `OrderNumber`) invites invalid-state bugs and forces re-validation everywhere it's used. A small
  enum/value type validates once at the boundary and is trusted everywhere after, removing a whole class of
  tests. (No single canonical Sonar/CA rule ID for this smell specifically.)
- **Anemic domain model.** Business rules live entirely in services acting on plain data-bag entities
  instead of on the model itself. Testing a rule then means standing up a service (often integration-
  shaped) rather than exercising a small pure method on the model — pulling logic onto the model turns many
  "integration-flavored" tests into cheap unit tests. See `unit-tests.md`'s scoping check for how this
  smell causes work to be mis-scoped as integration testing.
- **Hidden static/global state.** Static singletons, ambient `DateTime.Now`/`Guid.NewGuid()` calls inside
  logic, or service-locator patterns make behavior non-deterministic and hard to isolate in a unit test.
  (`S2223` — static mutable field visible outside its class.)
- **God methods/classes.** A method doing validation, persistence, and business logic together forces every
  test through all three; splitting responsibilities lets each be tested independently and cheaply.
  (`S1200` — class coupled to too many other classes; `S3776` — cognitive complexity too high.)
- **Untestable time/randomness.** Logic that reads the system clock or RNG directly instead of through an
  injectable abstraction can't be tested for edge cases (midnight rollovers, leap years, specific seeds).
- **Boolean parameter soup.** Methods with several boolean flags controlling behavior are a sign of hidden
  branching that's easy to under-test; consider whether the flags represent a state/strategy that should be
  named explicitly. (Related to `S107` — too many parameters — when the flags also pile up in count.)
- **Missing seams at framework boundaries.** Direct instantiation of `HttpClient`, file I/O, or DB access
  inside business logic (instead of behind an injectable interface) forces every test through the real
  dependency or forces heavy mocking. (`CA1062` for the argument-validation angle; no single Sonar/CA rule
  for the seam itself.)

## DDD / F#-inspired smells (apply equally well to C#)

- **Illegal states representable.** A type allows combinations of its fields that are actually invalid at
  runtime (e.g. three independent nullable/boolean fields modeling a state that's really one of four named
  states). Prefer a smaller type — an enum, a discriminated-union-style class hierarchy, or a record with a
  private constructor plus named factory methods — that makes the invalid combination fail to compile or
  fail to construct, instead of requiring a runtime check (and a test for that check) everywhere the type
  is used.
- **Large impure functions mixing decision logic with I/O.** When a method both decides something and
  performs a side effect (DB write, HTTP call, file write) in the same body, the decision logic can't be
  tested without the side effect. Extract the pure decision function (inputs in, decision out, no I/O) and
  test that in isolation; keep the impure shell thin enough that it barely needs testing itself.
- **Partial functions and silent nulls.** A method whose signature promises a value but can throw or return
  null for some inputs, with nothing in the signature warning callers, forces defensive tests at every call
  site. Prefer a total function (handles all inputs, e.g. via a `TryParse`-style signature or an explicit
  result/option type) so "no valid answer" is an explicit, testable outcome rather than an exception path
  callers may forget to test for.
- **Small, single-purpose functions over long procedural ones.** A long method mixing several
  responsibilities needs many test cases to cover all of its internal paths at once. Several small
  functions, each doing one thing, can each be covered with a handful of focused tests — mirroring F#'s
  bias toward small composable functions over large procedural blocks.
- **Mutable state by default.** Settable properties and mutable collections (`List<T>`, `Dictionary<K,V>`)
  let any code path mutate shared state between a test's Arrange and Assert steps, producing order-dependent
  or flaky tests and requiring defensive cloning in setup. Prefer `record` types with `init`-only setters
  and `with`-expressions for copies, and expose `IReadOnlyList<T>`/`ImmutableArray<T>` instead of a mutable
  collection — the object you Arrange is then guaranteed to be the object you Assert against. More
  fundamentally, immutability doesn't just make that test easier to write: it *eliminates* whole bug classes
  (unintended aliasing, a caller mutating shared state, thread-safety issues from concurrent mutation)
  outright, so there's no bug left in that category for any test to need to catch. (`CA2227` — collection
  properties should be read-only; `CA1002` — do not expose generic lists.)
- **Non-exhaustive branching.** A `switch`/`if-else` chain with a catch-all `default` over an enum or
  union-style type silently swallows a newly added case — existing tests stay green while the new case is
  mishandled at runtime, giving a false sense of coverage. Prefer a `switch` *expression* without a discard
  arm (the compiler warns on missing enum members) so adding a case breaks the build instead of passing
  silently, mirroring F#'s exhaustive `match` warnings. This is the purest form of angle (b): a compiler
  error stands in for the test entirely — no test can forget to cover a case the compiler already rejects.
- **Reference equality hiding value differences.** A domain type left as an ordinary class compares by
  reference, so `Assert.Equal(expected, actual)` only passes if both sides are the same object reference —
  rarely the intent — forcing brittle property-by-property assertions that silently stop covering a newly
  added field. This isn't only a test-authoring inconvenience: a hand-rolled or forgotten `Equals` override
  that omits a field is a real production bug (two "equal" records treated as different, or vice versa) that
  exists whether or not a test ever exercises it. Prefer a `record`/`record struct` for domain value types:
  compiler-generated structural equality means a single `Assert.Equal` covers every field automatically,
  including ones added later, and there's no hand-written override left to get wrong. (`CA1815` — override
  `Equals`/`==` on value types that need value semantics.)
- **Exceptions as control flow for expected business outcomes.** Communicating an expected outcome like
  "validation failed" via a thrown exception forces tests into `Assert.Throws<T>` with fragile message-text
  matching, and makes multi-step pipelines hard to test in isolation (the first failure throws, so
  downstream handling can't be exercised independently). This is a broader, pipeline-composition version of
  "Partial functions and silent nulls" above — prefer a `Result<TSuccess, TError>`-style return, chained
  with `Select`/`SelectMany` or `switch` expressions, so each step is independently testable and the whole
  chain is asserted on its final result value, not a caught exception.
