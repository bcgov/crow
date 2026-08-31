# .NET + SQL Server integration tests

Applies to .NET projects using Entity Framework Core against SQL Server. Detect first, default second — same
rule as `dotnet/unit-tests.md`.

## Study the existing suite before generating anything

If an integration test project already exists with real tests in it, **read a representative test class, its
base class, and its infrastructure/fixture helpers before writing code.** Test infrastructure encodes
hard-won decisions — isolation model, seeding conventions, cleanup ordering — that are invisible from a
package list and often absent from the project's own documentation. Follow what you find over the defaults
below; if you deliberately deviate, say so and why.

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
- Project scalar fields when asserting persisted EF state (e.g. `.Select(x => new { x.Id, x.Field })`)
  rather than asserting whole entities — avoids noisy failure messages from circular navigation properties.

## What is real, and what is mocked

Draw the line at the **process boundary**. Real: the database, `DbContext`, repositories, unit-of-work, and
the service under test. Mocked: external systems — search indexes, email/notification senders, third-party
HTTP APIs, message buses.

Mocking the repository or `DbContext` means the test proves nothing the unit tests didn't. If that's where
you're heading, re-check `unit-tests.md`'s scoping check; you probably want a unit test.

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
