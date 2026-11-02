# Analyzer-clean .NET test code

Load when generating or editing C# test code, **before writing it**, and again at the verification gate.
Generated tests that trip xUnit, Roslyn (`CAxxxx`), or SonarAnalyzer (`Sxxxx`) rules force a remediation
pass later, so write them clean the first time. This is a generation checklist, not an exhaustive rule list:
the project's own analyzers are the authority (see "Verification gate").

Rule IDs below are cited so a reviewer can look them up and so a warning in the build maps back to a
decision here. Verify an ID against the installed analyzer version before quoting it in a report; xUnit
analyzer numbering has shifted between releases.

## Generation checklist

| Writing... | Do | Rule (analyzer) |
|---|---|---|
| A skipped or scratch test | Committed scratchpad and environment-dependent skips are fine, but skip at runtime: make `Assert.Skip("reason");` (or `Assert.SkipUnless(...)`/`Assert.SkipWhen(...)`) the first statement of the test body (xUnit v3). Do not use the `[Fact(Skip = "...")]` attribute form. xUnit v2 has no `Assert.Skip`. | xUnit1004 (xunit.analyzers) |
| `[Theory]` data | Use `TheoryData<T1, T2>` or `TheoryDataRow<T>` with **xUnit-serializable** argument types (primitives, strings, enums, `DateTime`/`DateOnly`, and types implementing `IXunitSerializable`). Ordinary records and classes are **not** serializable even when all members are primitives. For anything else, pass a key/identifier and build the object inside the test, or accept that the row is not individually discoverable (xUnit1044/1045). Avoid `object[]` rows. | xUnit1045, xUnit1044 (xunit.analyzers) |
| `Assert.Single(...)` | Use its return value (`var item = Assert.Single(list);`) instead of asserting the count and then indexing `list[0]`. | xUnit2033 as reported in practice; xUnit2013 covers count checks (xunit.analyzers) |
| Async calls with a `CancellationToken` overload | Pass `TestContext.Current.CancellationToken` (xUnit v3 only). See `../dotnet/unit-tests.md` § "xUnit v3 cancellation and xUnit1051" for when not to. | xUnit1051 (xunit.analyzers) |
| Helper methods and builders | Mark methods that touch no instance state `static`. | CA1822 (Roslyn) |
| `IDisposable` test classes or fixtures | Implement the full dispose pattern and call `GC.SuppressFinalize(this)`. Prefer `IAsyncLifetime` / `IAsyncDisposable` for async teardown. | CA1816, CA1063 (Roslyn) |
| Placeholder or marker types | Do not generate empty classes, unused private members, unused parameters, or unused locals. If a type is only a marker, ask whether it is needed. | S2094, S1144, S1172, S1481 (SonarAnalyzer) |
| String literals | Reuse a `const`, a builder default, or a `TheoryData` row when the same literal appears three or more times in a class. Two or fewer: leave inline; do not invent a shared constants class for test data. | S1192 (SonarAnalyzer) |
| `JsonSerializerOptions` | Declare once as `static readonly`; never `new` it per call or per test. | CA1869 (Roslyn) |
| Logging in tests or test helpers | Use message templates, not interpolated strings, and avoid expensive argument computation. Do not add logging solely to narrate a test. | CA1873, CA2254 (Roslyn) |
| `catch` blocks in helpers | Never catch only to swallow. If the block handles the error locally and logs it, pass the caught exception to the logger. If it rethrows (`throw;`), do not also log it: log-and-rethrow is what S2139 rejects. | S6667, S2139 (SonarAnalyzer) |
| Retry or polling loops | Use a bounded loop or helper with a terminal unguarded attempt; avoid `catch ... when` filters that look unconditional. | S1994 (SonarAnalyzer) |
| Time and dates | Do not call `new DateTime(y, m, d)` without a kind; use `DateTimeKind.Unspecified`/`Utc` explicitly, or `DateOnly` for pure calendar dates. Prefer `TimeProvider` over `DateTime.Now`. | S6562 (SonarAnalyzer) |
| Awaiting | Use awaitable counterparts (`await Console.Error.WriteLineAsync`) inside async methods; never block with `.Result` or `.Wait()`. | S6966, xUnit1031 (SonarAnalyzer, xunit.analyzers) |
| Namespaces | Every type lives in a named namespace; no types in the global namespace. | S3903 (SonarAnalyzer) |
| Methods with many parameters | Past about seven parameters, use a builder or object initializer rather than a long factory signature. | S107 (SonarAnalyzer) |

## Do not "fix" by suppressing

- Do not add `#pragma warning disable`, `[SuppressMessage]`, `NoWarn`, or `.editorconfig` severity overrides
  to make generated tests pass. Fix the code. If a rule is genuinely wrong for a test pattern, record the
  narrowest member-level suppression with a rationale and tell the user, as the xUnit1051 guidance already
  requires.
- Rules that fire on EF Core query expressions (for example nested ternaries, S3358) are often unsafe to
  rewrite without running the query against the database. Flag them, don't rewrite them in test code that
  exercises a query.

## Verification gate

After generating or editing tests, before reporting completion:

1. Build the **test project** with warnings visible: `dotnet build <test.csproj> --no-restore -v q`. If the
   repo already promotes specific warnings to errors, use its existing settings; `-warnaserror` takes
   explicit diagnostic IDs (for example `-warnaserror:xUnit1004,CA1822`), not wildcard families. Do not add
   `TreatWarningsAsErrors` to the project for this check.
2. Read every `xUnit*`, `CA*`, `S*`, and `CS*` warning in the files you touched. Fix them. Warnings in
   files you did not touch are pre-existing; report them, do not fix them in this engagement.
3. Run the touched tests.
4. If the repository has no `.editorconfig` or no analyzers configured, say so and recommend loading
   `crow-application-development` `modules/dotnet/editorconfig-analyzers.md`; do not create or change the
   repository-wide analyzer configuration from the testing engagement.

## Sources

- xunit.analyzers rule index: <https://xunit.net/xunit.analyzers/rules/>
- Microsoft Learn, [.NET code-quality rules](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/)
- SonarSource, [C# rules](https://rules.sonarsource.com/csharp/)
