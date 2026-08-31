# Choosing a database test harness

Load when deciding **how a test will reach the database**. Answer this before writing any test code — the
choice determines seeding, cleanup, and isolation, and switching later means rewriting all three.

## Decision table

| Harness | Use when | Isolation mechanism |
|---|---|---|
| **EF + real database + fixtures** | The logic under test is C#/EF (services, repositories, business rules) | Explicit seeding with reserved IDs, explicit teardown |
| **Raw-SQL transaction rollback** | The logic under test is *only* SQL (triggers, computed columns, constraints) with no C#/EF path | One transaction per test, always rolled back, never committed |
| **Legacy T-SQL harness** | Stored procedures/functions with no EF code path, exercised as scripts | See [`../legacy-tsql-harness.md`](../legacy-tsql-harness.md) |

## EF + real database + fixtures

The default for anything with a C# code path. Uses a real `DbContext` against a real DEV/TEST database, so
constraints, computed columns, triggers, and query translation all behave as in production.

Cost: you own seeding and cleanup explicitly. See [`fixtures.md`](fixtures.md),
[`seeding-and-ids.md`](seeding-and-ids.md), and [`cleanup-and-isolation.md`](cleanup-and-isolation.md).

**Disqualifier:** none for C#-path logic — this is the baseline.

## Raw-SQL transaction rollback

For logic that lives entirely in the database. Open a connection, begin a transaction, do everything inside
it, and **always roll back** in teardown — never commit.

Why it's attractive when it fits:
- Nothing is ever persisted, so rollback undoes every side effect *including* audit/trigger inserts into
  other tables, automatically and in the right dependency order.
- **No cleanup code at all**, and no reserved-ID convention needed — ordinary identity-generated IDs are
  fine, because they never commit.

Shape: a base class implementing the framework's async lifetime hooks, opening the connection and beginning
the transaction on initialize, rolling back and disposing on dispose, with `Execute`/`QueryScalar`/`Query`
helpers that attach the shared transaction to every command.

**Disqualifiers:**
- **Any test needing two separate concurrent commits** (concurrency/race simulation, or asserting what a
  *second* connection can see). Uncommitted work is invisible outside its own transaction.
- Logic spanning C# and SQL — you'd be testing only half of it. Use the EF harness.

## Legacy T-SQL harness

Stored procedures and functions with no EF path, run as scripts. Being a stored procedure is **not by itself**
evidence of legacy design — bulk/set-based work is often correctly implemented there. See
[`../legacy-tsql-harness.md`](../legacy-tsql-harness.md).

## Mixing harnesses

One project can use all three; pick per test class, not per project. Keep them in separate folders and base
classes so the isolation model is obvious from the file you're reading.
