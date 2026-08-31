# Stored-procedure-only test harness (no EF code path)

For the case where the logic under test is a stored procedure or function with **no EF Core code path** at
all — don't force this into the EF/xUnit integration pattern in `dotnet/integration-tests.md`. This is not
automatically a "legacy" case: staying in T-SQL is often the deliberate, correct choice for set-based,
large-data-volume, or performance-sensitive operations, and an existing, well-tested procedure doing this
kind of work isn't a migration candidate just because it exists.

## Context initialization

Before generating anything, read whatever authoritative rules/spec doc and scenarios doc already exist for
the procedure's business logic (the same scenario-doc-first materials produced elsewhere in this skill) —
don't infer the procedure's intended behavior from its SQL alone if a spec exists.

## Approach

- Invoke the stored procedure directly via Dapper or a raw `SqlConnection`, not through EF Core.
- Prefer a disposable or dedicated test database. For an explicitly approved shared DEV/TEST database, run
  the same fail-closed server/database allowlist check required by
  [`integration/environment-and-diagnostics.md`](integration/environment-and-diagnostics.md).
- **Wrap setup, execution, and assertions in a transaction that's always rolled back**
  (`BEGIN TRANSACTION` ... seed ... `EXEC` ... assert ... `ROLLBACK TRANSACTION`). This guarantees the
  database is left pristine when the connection remains healthy, without relying on cleanup code that could
  be skipped by a failing assertion.
- Tag seeded rows with a unique run identifier and use distinct generated values per scenario. Key sign alone
  is not proof of ownership if a rollback or connection fails.
- Document required assertions as enumerated, named blocks (`Assertion 1: <name>`, `Assertion 2: <name>`,
  ...), each with a one-line intent and the concrete query/check that proves it — this keeps a stored
  procedure's expected behavior reviewable even though it can't be expressed as ordinary EF entity
  assertions.
- Assert against the procedure's actual side effects (rows changed, output parameters, result sets) rather
  than re-implementing its logic in the test — the test should catch behavioral drift, not restate the
  procedure.
- Keep this pattern isolated to the specific procedure(s) that have no EF equivalent; don't let it become
  the default for new SQL-backed logic. New logic should go through EF Core so it can use the standard
  integration pattern, unless there's a genuine set-based/performance reason to write it as a procedure.
- Only record a procedure as a migration candidate (non-blocking finding in
  `docs/testing/testability-notes.md`) when it genuinely looks like an artifact of an older approach with
  no reason to stay T-SQL-only — not simply because it's a stored procedure.
