# .NET + SQL Server integration tests

Applies to .NET projects using Entity Framework Core against SQL Server. Detect first, default second — same
rule as `dotnet/unit-tests.md`.

## Study the existing suite before generating anything

If an integration test project already exists with real tests in it, **read a representative test class, its
base class, and its infrastructure/fixture helpers before writing code.** Test infrastructure encodes
hard-won decisions — isolation model, seeding conventions, cleanup ordering — that are invisible from a
package list and often absent from the project's own documentation. Follow what you find over the defaults
below; if you deliberately deviate, say so and why.

This covers **infrastructure decisions, not language idiom** — an old C# style in an existing suite records
when it was written, not a decision to keep writing it. See
[`../reference/language-features-for-testability.md`](../reference/language-features-for-testability.md).

## Default pattern (only when no integration test project exists yet)

- Use a **real `DbContext` against a real SQL Server database** (the project's DEV/TEST environment), not
  `Microsoft.EntityFrameworkCore.InMemory` — the in-memory provider hides real constraint, collation, and
  query-translation behavior.
- No Testcontainers (may not be available in the target environment), no Respawn-style full DB reset (tests
  typically run against a **shared** DEV/TEST database used by other developers), no tSQLt (not worth
  adopting once logic has migrated to EF Core). If the project already uses any of these, follow the
  project's existing choice instead.
- Seed test rows with explicit **negative primary keys** so they can never collide with real DEV/TEST data.
  This has real mechanics attached (identity inserts, connection pooling, idempotent re-seeding) — see
  [`reference/integration/seeding-and-ids.md`](../reference/integration/seeding-and-ids.md) before writing
  seeding code.
- Tag integration tests distinctly from unit tests (e.g. `[Trait("Category","Integration")]`) so they can be
  run/excluded separately.
- Decide **where the test enters the system** — directly at the service, or as a real HTTP request against
  the app hosted in-process (`WebApplicationFactory<Program>`). Entering at HTTP covers routing, model
  binding, validation, auth, and middleware in the same test and survives internal refactoring, at the cost
  of speed and failure-message precision. See
  [`reference/integration/harness-selection.md`](../reference/integration/harness-selection.md).

## What is real, and what is mocked

**Fake only what you don't own.** Ownership is the test, not distance — the database is in another process
and still stays real, because your team controls its schema and constraints. Real: the database,
`DbContext`, repositories, unit-of-work, and the service under test. Faked: what you don't control —
payment gateways, email/notification providers, search indexes, third-party HTTP APIs, message brokers.

Mocking the repository or `DbContext` means the test proves nothing the unit tests didn't. If that's where
you're heading, re-check `unit-tests.md`'s scoping check; you probably want a unit test.

## Asserting persisted state

- **Read back through a fresh scope/context.** Asserting through the same `DbContext` the operation used
  shows you the change tracker, not the database — the test passes on state that was never saved.
- **Filter by an identifier the test supplied**, never `SingleAsync()` over the whole table. A test that
  assumes it's the only writer breaks the moment it isn't, and the failure looks unrelated to the cause.
- **Assert both halves of the contract.** When an operation is expected to fail, also assert that nothing
  was written — a rejection that quietly persisted a row is exactly the defect an integration test is for.
- Project scalar fields (e.g. `.Select(x => new { x.Id, x.Field })`) rather than asserting whole entities —
  avoids noisy failure messages from circular navigation properties.

## Where the detail lives

This module stays deliberately thin. Load the one reference file matching the decision in front of you:

| Decision in front of you | Load |
|---|---|
| How should this test reach the database at all? | [`harness-selection.md`](../reference/integration/harness-selection.md) |
| Writing/reviewing a fixture; per-test vs shared lifetime | [`fixtures.md`](../reference/integration/fixtures.md) |
| Writing seeding code, builders, or ID allocation | [`seeding-and-ids.md`](../reference/integration/seeding-and-ids.md) |
| Writing teardown; FK errors; flaky cross-test state; parallelism | [`cleanup-and-isolation.md`](../reference/integration/cleanup-and-isolation.md) |
| Project/connection wiring, or an opaque failure needing better signal | [`environment-and-diagnostics.md`](../reference/integration/environment-and-diagnostics.md) |

Start at `harness-selection.md` when opening a new integration test area — the harness choice determines
seeding, cleanup, and isolation, so making it first avoids rework.

## The one exception: pure T-SQL with no EF code path

If the logic under test is a stored procedure/function with no EF Core code path at all, don't force it into
this pattern (this isn't automatically a legacy case — see the file for why) — see
[`reference/legacy-tsql-harness.md`](../reference/legacy-tsql-harness.md) (load only when
this specific case applies).

## Connection & environment

- Integration tests run against DEV and optionally TEST — never UAT or PROD.
- Connection string via configuration, never a committed secret — only a placeholder in source control.
  Layering, fail-fast wiring, and diagnostics:
  [`environment-and-diagnostics.md`](../reference/integration/environment-and-diagnostics.md).
