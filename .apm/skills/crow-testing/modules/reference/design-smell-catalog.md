# Design-smell catalog (testability)

Deeper catalog of design choices that make testing unnecessarily hard. Use during `discovery.md` scans when
the compact list there isn't enough. Each item is a candidate non-blocking finding for
`docs/testing/testability-notes.md` — flag, don't fix, unless asked.

- **Nullable-but-required fields.** A nullable property validated as required at every call site is simpler
  as a non-nullable type; the validation (and its tests) disappear entirely.
- **Primitive obsession on constrained values.** A raw `string`/`int` standing in for a bounded set of valid
  values (status codes, roles) invites invalid-state bugs that a small enum/value type would prevent by
  construction, removing a class of tests.
- **Hidden static/global state.** Static singletons, ambient `DateTime.Now`/`Guid.NewGuid()` calls inside
  logic, or service-locator patterns make behavior non-deterministic and hard to isolate in a unit test.
- **God methods/classes.** A method doing validation, persistence, and business logic together forces every
  test through all three; splitting responsibilities lets each be tested independently and cheaply.
- **Untestable time/randomness.** Logic that reads the system clock or RNG directly instead of through an
  injectable abstraction can't be tested for edge cases (midnight rollovers, leap years, specific seeds).
- **Boolean parameter soup.** Methods with several boolean flags controlling behavior are a sign of hidden
  branching that's easy to under-test; consider whether the flags represent a state/strategy that should be
  named explicitly.
- **Missing seams at framework boundaries.** Direct instantiation of `HttpClient`, file I/O, or DB access
  inside business logic (instead of behind an injectable interface) forces every test through the real
  dependency or forces heavy mocking.
