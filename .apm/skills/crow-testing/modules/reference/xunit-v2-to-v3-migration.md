# xUnit v2 to v3 migration

Load when an existing .NET test project uses xUnit v2. Use it first to assess migration cost, then obtain
explicit user confirmation before applying any migration step. Do not load this module for a new project or
an existing xUnit v3 suite.

## Assess the migration

Offer migration for a standard v2 suite:

- `[Fact]`/`[Theory]`, `IClassFixture<T>`, `ITestOutputHelper`, and optional `IAsyncLifetime`;
- `xunit` plus optional `xunit.runner.visualstudio` package references; and
- a target framework already at .NET 8.0+ or .NET Framework 4.7.2+.

Treat these as high-cost blockers and follow the existing v2 suite unless the user explicitly approves a
larger migration:

- custom `ITestFramework`, `TestFrameworkAttribute`, or `IXunitTestCaseDiscoverer`;
- custom theory data-source infrastructure;
- heavy reliance on `Xunit.Abstractions` beyond `ITestOutputHelper`;
- non-standard runners, custom AppDomain hosts, or in-tree framework forks; or
- a target framework below the v3 floor that cannot be raised.

Migration is never automatic. New tests must not land on v3 alongside a still-v2 suite unless the user
explicitly chooses that mixed path.

## Standard v2 to v3 migration steps

1. Raise the test project's TFM to `net8.0`+ or `net472`+ if not already there.
2. Replace `<PackageReference Include="xunit" ...>` with
   `<PackageReference Include="xunit.v3" ...>`. Remove `xunit.runner.visualstudio` unless the project
   explicitly needs the classic VSTest bridge. If VSTest is required, keep
   `xunit.runner.visualstudio` at a version compatible with xUnit v3.
3. Set the test project as an executable and enable the MTP entry point: set `<OutputType>` to `Exe`
   and set `<UseMicrosoftTestingPlatformRunner>true</UseMicrosoftTestingPlatformRunner>`. xUnit v3
   requires executable output; the MTP property selects the Microsoft Testing Platform entry point.
4. Update every `IAsyncLifetime.InitializeAsync` / `IAsyncLifetime.DisposeAsync` return type from `Task` to
   `ValueTask`. This is the API-shape edit that ripples into integration fixtures.
5. Review fixtures and test classes that implement both `IDisposable` and `IAsyncDisposable` (including
   `IAsyncLifetime`). xUnit v3 calls `DisposeAsync` instead of both disposal paths, so consolidate cleanup
   there or explicitly call the required synchronous cleanup from `DisposeAsync`.
6. Delete `using Xunit.Abstractions;` lines. v3 exposes the remaining abstractions under the `Xunit`
   namespace.
7. Run the v3 analyzers (`xunit.analyzers` on the v3 line) and resolve their diagnostics.
8. If the project runs in CI/CD, follow the general MTP test-result guidance in
   [`unit-tests.md`](../dotnet/unit-tests.md#ci-test-result-publishing-mtp).

## Cancellation during migration

After migration, apply the canonical
[`xUnit v3 cancellation and xUnit1051`](../dotnet/unit-tests.md#xunit-v3-cancellation-and-xunit1051)
guidance. In particular, do not turn the migration into blanket token boilerplate for fast assertion-only
queries, and do not reference `TestContext.Current` from production code.
