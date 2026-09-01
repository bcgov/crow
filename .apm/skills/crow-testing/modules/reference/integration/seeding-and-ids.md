# Seeding and test IDs

Load when writing seeding code or test data builders for a database-backed integration test.

## Reserved-ID convention

Identity columns only ever generate **positive** values, so **negative IDs can never collide with real
data**. Seed test rows with explicit negative primary keys: they're identifiable by sign programmatically,
and safe to sweep.

Pair the sign convention with a **visible tag prefix** on a text column (`IntTest-`), so seeded rows are
recognizable to a human in the UI or a query result, not just to code. See
[`environment-and-diagnostics.md`](environment-and-diagnostics.md).

## Two ID lifetimes

| Allocator | Use for | Why |
|---|---|---|
| `NextNegativeId()` — sequential counter | Rows the test creates and tears down | Predictable, easy to sweep |
| `NextRetainedNegativeId()` — random | Rows deliberately left behind (e.g. reference users other rows point at) | Random allocation avoids colliding with a later run's counter restarting at -1 |

```csharp
private static long _nextId = -1;
public static int NextNegativeId() => (int)Interlocked.Decrement(ref _nextId);

public static int NextRetainedNegativeId() => -RandomNumberGenerator.GetInt32(1, int.MaxValue);
```

Use `Interlocked` even if tests currently run sequentially — the cost is nil and it removes a landmine if
parallelism is enabled later.

For retained rows, wrap seeding in a **duplicate-key retry** (catch the driver's unique/PK-violation error
numbers, clear the change tracker, allocate a new ID, retry a bounded number of times). Random IDs collide
rarely, but "rarely" across a long-lived shared database means eventually.

## Seed idempotently: delete-then-insert

**Always delete any pre-existing row for the key before inserting it**, rather than relying on teardown
alone:

```csharp
await ExecuteInTransactionAsync(context, async () =>
{
    await deleteExistingAsync();     // this row + its dependents
    await IdentityInsertHelper.ExecuteAsync(context, "dbo.order", async () =>
    {
        context.Orders.Add(entity);
        await context.SaveChangesAsync();
    });
});
```

The reason is specific and easy to miss: **test frameworks do not run teardown when setup throws.** If
`InitializeAsync` fails partway, `DisposeAsync` never runs and the rows already written are orphaned — so
the *next* run hits a key violation on IDs it expected to be free. Idempotent seeding makes the suite
self-healing after any crash, abort, or debugger stop.

Scope the delete correctly: a builder owns **its own table's row**. Dependent rows written by other tables,
triggers, or side effects belong to the fixture composing the scenario — only it knows every table the code
under test touches. See [`cleanup-and-isolation.md`](cleanup-and-isolation.md).

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
