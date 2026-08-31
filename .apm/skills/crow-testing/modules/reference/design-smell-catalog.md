# Design-smell catalog (testability)

Deeper catalog of design choices that make testing unnecessarily hard. Use during `discovery.md` scans when
the compact list there isn't enough. Each item is a candidate non-blocking finding for
`docs/testing/testability-notes.md` — flag, don't fix, unless asked.

## The one thing every entry has in common

Read this catalog through `foundation.md`'s **band-pass filter model**. Every smell here does the same
thing: **it forces a defect class to be caught at a later, more expensive filter than necessary.** The fix
always moves the defect earlier.

That displacement happens in one of two ways:

- **(a) The defect can't be caught at the filter that should catch it.** Hidden static state, a missing
  seam, or a god method makes the behavior unreachable from a unit test, so the defect escapes to
  integration, manual QA, or production.
- **(b) The defect is caught at an *earlier* filter than tests — so the test shouldn't need to exist.**
  Non-nullable types, exhaustive matching, and unrepresentable invalid states push the defect down to
  **filter stage zero, the compiler.** These are the highest-value fixes in the catalog: they don't make a
  test easier to write, they delete the test's reason to exist.

The biggest filter jump is usually the biggest win. Use that to rank findings — see
[`testability-improvements.md`](testability-improvements.md) for how to turn an entry here into a
prioritized, justified recommendation, and when *not* to recommend a change at all.

## Triage table

| Smell | Defect caught today at | Could be caught at | Rule |
|---|---|---|---|
| Nullable-but-required fields | Unit (or runtime) | **Compiler** | nullable analysis, `CA1062` |
| Primitive obsession | Unit, repeatedly per call site | **Compiler** | — |
| Illegal states representable | Unit, repeatedly per call site | **Compiler** | — |
| Non-exhaustive branching | Runtime (tests stay green) | **Compiler** (`CS8509`) | `CS8509` |
| Reference equality hiding value differences | Runtime / brittle unit assertions | **Compiler** (generated equality) | `CA1815` |
| Mutable state by default | Runtime (aliasing, concurrency) | **Compiler** (`init`, read-only) | `CA2227`, `CA1002` |
| Anemic domain model | Integration | Unit | — |
| Large impure functions mixing decision logic with I/O | Integration | Unit | — |
| God methods/classes | Integration | Unit | `S1200`, `S3776` |
| Missing seams at framework boundaries | Integration | Unit | — |
| Hidden static/global state | Integration, flakily | Unit | `S2223` |
| Long procedural methods | Unit, with many cases at once | Unit, few cases each | `S3776` |
| Boolean parameter soup | Unit, under-tested branches | Unit, named branches | `S107` |
| Partial functions and silent nulls | Runtime, at every call site | Unit, one explicit outcome | — |
| Exceptions as control flow | Unit, via brittle throw assertions | Unit, on a returned result | — |
| Untestable time/randomness | **Production** | Unit | — |

Where a real SonarQube/Microsoft rule exists it's noted for stronger justification when handing off; `—`
means no canonical rule ID exists for that smell, stated plainly rather than invented.

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
