# Design-smell catalog (testability)

Deeper catalog of design choices that make testing unnecessarily hard. Use during `discovery.md` scans when
the compact list there isn't enough. Each item is a candidate non-blocking finding for
`docs/testing/testability-notes.md` — flag, don't fix, unless asked. Where a real SonarQube/Microsoft rule
exists, it's noted for stronger justification when handing off; where none exists, that's stated plainly
rather than invented.

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
