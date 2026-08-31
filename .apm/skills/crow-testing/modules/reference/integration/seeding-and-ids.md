# Seeding and test IDs

Load when writing seeding code or test data builders for a database-backed integration test.

## Establish run ownership

Primary-key values do not prove that a row belongs to a test. SQL Server identity seeds and increments are
configurable, natural keys and GUIDs have different collision properties, and multiple test processes can
reuse process-local counters.

Create a cryptographically random run identifier for each test run and persist `IntTest-{RunId}-` in a
visible text field on every seeded root. Keep the exact keys created by the fixture in memory. Cleanup may
delete only rows matched by those exact keys and, where available, the same run marker.

For integer identity keys, a random negative candidate can make test data recognizable, but it is only a
candidate:

```csharp
public static int NextCandidateId() => -RandomNumberGenerator.GetInt32(1, int.MaxValue);
```

On a duplicate-key result, clear the change tracker, allocate another candidate, and retry a bounded number
of times. Never delete the colliding row; it is not owned by the current run. For GUID or natural keys, embed
the run identifier in the generated value where the schema permits.

Do not deliberately retain rows after a run. If a shared reference record is unavoidable, provision it
outside the test suite through an explicitly reviewed environment setup process.

## Insert without destructive pre-cleaning

Do not use delete-then-insert for a candidate key. A previous row with that key may belong to another test
process or to non-test data. Generate a new run-owned key instead.

Setup failures can bypass fixture disposal. Put cleanup in a `finally` block around each completed seeding
phase where the framework permits it, and provide a separate, explicitly reviewed maintenance operation for
stale rows identified by their full run marker. Never make ordinary test startup sweep rows by key sign or a
generic prefix. See [`cleanup-and-isolation.md`](cleanup-and-isolation.md).

## Inserting explicit identity values

Supplying an explicit primary key for an identity column requires
`SET IDENTITY_INSERT <table> ON` before the insert and `OFF` after. Two traps:

**1. It's connection-scoped, and pooling will silently defeat you.** Pooling issues `sp_reset_connection`
when a connection is handed back out, clearing session settings like `IDENTITY_INSERT`. If the `ON`
statement and the insert land on different physical connections the setting is gone — and the failure is
*intermittent*, appearing only when the pool happens to recycle between the two.

Fix: **explicitly open the connection and hold it open across the whole set-and-insert operation**, rather
than letting the ORM open and close it per command.

```csharp
public static async Task ExecuteInTransactionAsync(DbContext context, Func<Task> action)
{
    await context.Database.OpenConnectionAsync();          // hold one physical connection...
    await using var transaction = await context.Database.BeginTransactionAsync();
    try
    {
        await action();                                     // ...across IDENTITY_INSERT ON + INSERT + OFF
        await transaction.CommitAsync();
    }
    catch { await transaction.RollbackAsync(); throw; }
    finally { await context.Database.CloseConnectionAsync(); }
}
```

**2. Only one table at a time** may have `IDENTITY_INSERT ON` per session — turn it `OFF` before seeding the
next table. A helper that wraps ON/action/OFF in a `try`/`finally` makes this automatic.

## Builder shape

One builder per table, taking the context, accepting the explicit ID plus required foreign keys, defaulting
everything else, and offering a `configure` callback for per-scenario tweaks:

```csharp
public Task<Order> CreateAsync(int orderId, int customerId,
                               OrderStatus status = OrderStatus.None,
                               Action<Order>? configure = null)
```

Reload and return the persisted entity rather than the in-memory one, so the caller sees database-computed
columns and defaults. Document any column the database computes — EF ignores values assigned to those, and a
test that tries to force one will be quietly wrong.

General builder design (semantic composite methods, nested composition, determinism) is in
[`../test-data-builders.md`](../test-data-builders.md).
