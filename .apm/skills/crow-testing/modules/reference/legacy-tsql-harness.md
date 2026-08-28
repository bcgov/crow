# Legacy T-SQL harness pattern

For the rare case where the logic under test is a stored procedure or function with **no EF Core code path**
at all — don't force this into the EF/xUnit integration pattern in `dotnet/integration-tests.md`.

## Approach

- Invoke the stored procedure directly via Dapper or a raw `SqlConnection`, not through EF Core.
- Still use the negative-ID seeding convention from `dotnet/integration-tests.md` so seeded rows can never
  collide with real DEV/TEST data.
- Assert against the procedure's actual side effects (rows changed, output parameters, result sets) rather
  than re-implementing its logic in the test — the test should catch behavioral drift, not restate the
  procedure.
- Keep this pattern isolated to the specific legacy procedure(s) that have no EF equivalent; don't let it
  become the default for new SQL-backed logic. New logic should go through EF Core so it can use the
  standard integration pattern.
- If the procedure is a good candidate for migration to EF Core (i.e. no compelling reason to stay
  T-SQL-only), record that as a non-blocking finding in `docs/testing/testability-notes.md` rather than
  attempting the migration as part of writing its tests.
