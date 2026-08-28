# .NET + SQL Server integration tests

Applies to .NET projects using Entity Framework Core against SQL Server. Detect first, default second — same
rule as `dotnet/unit-tests.md`.

## Default pattern (only when no integration test project exists yet)

- Use a **real `DbContext` against a real SQL Server database** (the project's DEV/TEST environment), not
  `Microsoft.EntityFrameworkCore.InMemory` — the in-memory provider hides real constraint, collation, and
  query-translation behavior.
- No Testcontainers (may not be available in the target environment), no Respawn-style full DB reset (tests
  typically run against a **shared** DEV/TEST database used by other developers), no tSQLt (not worth
  adopting once logic has migrated to EF Core). If the project already uses any of these, follow the
  project's existing choice instead.
- **Negative-ID seeding convention:** give test-seeded rows explicit negative primary keys so they can never
  collide with real DEV/TEST data, and so seeded rows are trivially identifiable and cleanable. For
  `IDENTITY` columns this requires `SET IDENTITY_INSERT <table> ON` around the insert (and back `OFF`
  after) — EF Core will not otherwise let you supply an explicit key for an identity column. Clean up
  explicitly in the test's teardown (`DELETE ... WHERE Id < 0`, scoped to the seeded rows) since, unlike the
  T-SQL harness's `BEGIN TRANSACTION ... ROLLBACK` pattern, a normal EF Core test commits its changes to the
  shared database — don't rely on an ambient transaction unless the test explicitly wraps its own EF calls
  in one and rolls it back at the end.
- Tag integration tests distinctly from unit tests (e.g. `[Trait("Category","Integration")]`) so they can be
  run/excluded separately.
- Project scalar fields when asserting persisted EF state (e.g. `.Select(x => new { x.Id, x.Field })`)
  rather than asserting whole entities — avoids noisy failure messages from circular navigation properties.

## The one exception: pure T-SQL with no EF code path

If the logic under test is a stored procedure/function with no EF Core code path at all, don't force it into
this pattern (this isn't automatically a legacy case — see the file for why) — see
[`reference/legacy-tsql-harness.md`](../reference/legacy-tsql-harness.md) (load only when
this specific case applies).

## Connection & environment

- Integration tests run against DEV and optionally TEST — never UAT or PROD.
- Connection string via configuration, never a committed secret — only a placeholder in source control.
