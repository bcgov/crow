# Cleanup and test isolation

Load when writing teardown for a database-backed integration test, or when diagnosing foreign-key errors or
flaky cross-test state.

## The problem

Prefer a disposable database or one dedicated to automated tests. When an explicitly approved shared
DEV/TEST database is unavoidable, every test must leave unrelated rows untouched and remove its exact
run-owned footprint. Key sign and generic prefixes are not ownership proofs.

## Delete in foreign-key dependency order

Referencing rows must go before the rows they reference. A naive `DELETE FROM client WHERE client_id < 0`
fails on the first FK constraint it hits.

```csharp
private async Task PurgeAsync()
{
    // deepest dependents first...
    await ExecAsync("DELETE FROM dbo.order_audit WHERE order_id = @OrderId", new { OrderId });
    await ExecAsync("DELETE FROM dbo.order_line WHERE order_id = @OrderId", new { OrderId });

    // ...then the roots
    await ExecAsync(
        "DELETE FROM dbo.order WHERE order_id = @OrderId AND test_run = @RunId",
        new { OrderId, RunId });
    await ExecAsync(
        "DELETE FROM dbo.customer WHERE customer_id = @CustomerId AND test_run = @RunId",
        new { CustomerId, RunId });
}
```

Two things worth noting in that shape:

- **Parameterize every cleanup statement.** Even test-owned values should not be interpolated into SQL.
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
**verify empirically**: run the test once, then query for the current run identifier and exact fixture keys
across candidate tables. Anything still present is a table you missed. Never sweep all negative keys or every
row with a generic test prefix.

## Cleanup must run in failure paths

Framework disposal is not guaranteed when setup throws. Wrap completed seeding phases so exact run-owned rows
are removed in `finally`, and have fixture disposal call the same idempotent cleanup. Stale rows from an
aborted process require a separate reviewed maintenance operation that matches a full run marker and reports
what it will delete before mutation.

Order of operations in a fixture: **environment check -> allocate run ID -> seed -> test -> cleanup in
finally -> dispose**.

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
