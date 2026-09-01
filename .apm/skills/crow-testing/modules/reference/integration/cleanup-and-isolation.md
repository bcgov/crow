# Cleanup and test isolation

Load when writing teardown for a database-backed integration test, or when diagnosing foreign-key errors or
flaky cross-test state.

## The problem

Integration tests typically run against a **shared, persistent** DEV/TEST database — not a disposable
per-run container. Nothing resets it between runs, so every test is responsible for leaving the database as
it found it. A test that half-cleans doesn't just leak rows; it breaks the *next* run, and the failure
surfaces somewhere unrelated.

## Delete in foreign-key dependency order

Referencing rows must go before the rows they reference. A naive `DELETE FROM client WHERE client_id < 0`
fails on the first FK constraint it hits.

```csharp
private async Task PurgeAsync()
{
    // deepest dependents first...
    await Exec($"DELETE FROM dbo.deadline WHERE decision_id IN (SELECT decision_id FROM dbo.order_decision WHERE order_id = {OrderId})");
    await Exec($"DELETE FROM dbo.order_decision WHERE order_id = {OrderId}");
    await Exec($"DELETE FROM dbo.task     WHERE customer_id = {CustomerId}");
    await Exec($"DELETE FROM dbo.activity WHERE customer_id = {CustomerId}");

    // break a circular reference before deleting either side...
    await Exec($"UPDATE dbo.order SET auth_contact_id = NULL WHERE customer_id = {CustomerId}");
    await Exec($"DELETE FROM dbo.authorized_contact WHERE customer_id = {CustomerId}");

    // ...then the roots
    await Exec($"DELETE FROM dbo.order    WHERE customer_id = {CustomerId}");
    await Exec($"DELETE FROM dbo.customer WHERE customer_id = {CustomerId}");
}
```

Two things worth noting in that shape:

- **Circular or optional references need a null-out first.** When A references B and B optionally references
  A, neither can be deleted until one side's FK is cleared. `UPDATE ... SET fk = NULL` before the deletes.
- **Cleanup must cover tables the test never wrote to directly.** Triggers, audit tables, and cascading
  service logic all write rows on your behalf. The service under test decides the real footprint, not your
  seeding code.

## Discover the dependency order before writing cleanup

Don't guess it, and don't derive it from the ORM model alone — the database has constraints and triggers the
model may not express. Ask the database:

```sql
-- What references this table?
SELECT OBJECT_NAME(parent_object_id) AS referencing_table, name AS fk_name
FROM sys.foreign_keys
WHERE referenced_object_id = OBJECT_ID('dbo.client');

-- What does this table reference?
SELECT OBJECT_NAME(referenced_object_id) AS referenced_table, name AS fk_name
FROM sys.foreign_keys
WHERE parent_object_id = OBJECT_ID('dbo.client');

-- What triggers fire, and what do they write?
SELECT name, OBJECT_NAME(parent_id) AS on_table FROM sys.triggers WHERE is_disabled = 0;
```

Walk the referencing side recursively until you reach leaves; that reverse order is your delete order. Then
**verify empirically**: run the test once, then query for leftover rows with reserved IDs across the
candidate tables. Anything still present is a table you missed — a sweep helper
(`SELECT COUNT(*) FROM {table} WHERE {pk} < 0`) makes this cheap to assert in teardown and cheap to re-check
later for orphans from an earlier aborted run.

## Clean before seeding, not only after

Teardown is not guaranteed to run — most frameworks skip disposal when setup throws. So the fixture's first
act should be to purge its own footprint, making the suite self-healing after any crash or aborted debug
session. See [`seeding-and-ids.md`](seeding-and-ids.md) for the idempotent delete-then-insert pattern this
pairs with.

Order of operations in a fixture: **purge -> seed -> test -> dispose**.

## Parallelization against a shared database

**Default to running integration tests sequentially**, even when the isolation model is technically
parallel-safe:

```csharp
[assembly: CollectionBehavior(DisableTestParallelization = true)]
```

The reasoning is specific to the shared-database situation: the suite competes with real developers and QA
using the same box, so concurrent runs risk lock contention and timeouts that look like test failures but
aren't. While a suite is small, the runtime saved doesn't justify that noise.

Note this is the **opposite** default from a unit-test project, where parallelism is free and should stay on.
Set it explicitly in each project so neither inherits the other's assumption by accident, and record the
decision (plus its trigger for revisiting — usually "when sequential runtime becomes the bottleneck") in a
comment; it looks like an oversight otherwise.

Even while sequential, allocate IDs with an atomic counter (see [`seeding-and-ids.md`](seeding-and-ids.md))
so enabling parallelism later doesn't silently introduce collisions.
