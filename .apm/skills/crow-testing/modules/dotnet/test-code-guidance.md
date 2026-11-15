# C# test-code guidance

This guidance applies to C# unit tests, integration tests, fixtures, and helpers used only by tests. It is
not a repository-wide coding standard. If the project already has an `.editorconfig`, follow its relevant
test-code settings; do not add one as part of this guidance. Without one, these recommendations remain
scoped to test code and do not imply that the repository must adopt new rules or configuration.

Analyzer IDs are references to the kinds of findings these practices help avoid, not a requirement to
configure or enable every analyzer. Check the project's framework and analyzer versions before relying on
a rule ID.

## Test cases and data

For xUnit.v3 theories, use typed `TheoryData<T1, T2>` with xUnit-serializable values such as primitives,
strings, enums, `DateTime`, and types implementing `IXunitSerializable` (xUnit1044/xUnit1045). Ordinary
records and classes are not automatically serializable, even if their members are simple. For other values,
pass a key or identifier and construct the object inside the test, or accept that the data row is not
individually discoverable. Avoid untyped `object[]` rows.

When using xUnit.v3, check a single item with the value returned by `Assert.Single(list)` instead of
checking the count and then indexing (xUnit2033; count assertions may also trigger xUnit2013). A committed
scratchpad or environment-dependent xUnit.v3 test can skip at runtime: put `Assert.Skip("reason");` first
in the test body, or use the conditional skip APIs (xUnit1004). Do not use attribute skips with xUnit.v3.

For NUnit, MSTest, and other test frameworks, use their supported APIs and follow the existing suite
conventions for cancellation and skips. Do not apply xUnit-specific APIs or analyzer requirements to them.

## xUnit.v3 async tests and fixtures

In xUnit.v3, pass `TestContext.Current.CancellationToken` to responsive async APIs that accept a token
(xUnit1051). Follow the exception guidance in [`unit-tests.md`](unit-tests.md) for fast assertion-only
queries, and never pass test context into production code.

Keep test helpers stateless where possible; methods that do not use instance state can be `static` (CA1822).
For fixture disposal, follow the repository's established pattern. A simple fixture does not need an
invented finalizer or full dispose pattern; when a finalizer is defined, `Dispose()` should call
`GC.SuppressFinalize(this)` (CA1816/CA1063). Prefer the framework's async lifetime hooks for async teardown.

## Readable, analyzer-friendly test code

Avoid empty scaffolding, unused private members, parameters, and locals (S2094, S1144, S1172, S1481). Reuse
a constant, builder default, or theory row when a literal appears repeatedly in the same class (S1192), but
don't create shared constants for one-off test data.

If test helpers serialize JSON, cache and reuse `JsonSerializerOptions` rather than allocating them for
each call (CA1869). Avoid logging just to narrate test execution; when logging is part of the behavior under
test, use message templates and avoid expensive argument construction (CA2254/CA1873). A catch block that
handles and logs an error should pass the exception to the logger (S6667); if it rethrows with `throw;`, do
not also log it (S2139). Never catch an exception only to swallow it.

Use a bounded loop for retries and polling, and keep the loop's termination condition clear. In a `for`
loop, update its counter in the increment clause rather than incrementing a different variable there or
updating the counter only in the body (S1994). For test dates, use `DateOnly` for calendar dates and set
`DateTimeKind` explicitly when constructing `DateTime` (S6562); prefer an injected `TimeProvider` over
ambient current time where time-dependent behavior needs deterministic tests.

Keep test types in named namespaces (S3903), await asynchronous APIs rather than blocking with `.Result` or
`.Wait()` (xUnit1031), and avoid factories with many positional arguments. For larger test data,
prefer a builder or object initializer (S107).

Do not add warning suppressions just to make generated tests pass. Fix the test code; if a rule is a genuine
false positive, use the narrowest justified suppression and explain it. Warnings in untouched files are
pre-existing and should be reported, not folded into the test change. Analyzer findings on production EF
query expressions are outside test-code scope; don't rewrite those queries to silence a test build.

## Verification

Run the repository's formatter, build the test project without incremental compilation, and run the changed
tests. Review analyzer output for the files changed. These practices still apply if a project does not have
an analyzer that reports the corresponding rule; don't add or change repository-wide analyzer settings as
part of test work.

## Sources

- xunit.analyzers rule index: <https://xunit.net/xunit.analyzers/rules/>
- Microsoft Learn, [.NET code-quality rules](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/)
- SonarSource, [C# analyzer rule specifications](https://github.com/SonarSource/sonar-dotnet/tree/master/analyzers/rspec/cs)
