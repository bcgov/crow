# Choosing a database test harness

Load when deciding **how a test will reach the database**. Answer this before writing any test code — the
choice determines seeding, cleanup, and isolation, and switching later means rewriting all three.

## First: where does the test enter the system?

Orthogonal to the harness, and usually decided first. Both options below use a real database.

| Entry point | Test calls | Good when |
|---|---|---|
| **Service/handler** | The service class directly, with real dependencies constructed | The interesting behavior is in the service; routing and serialization are covered elsewhere |
| **HTTP, through an in-memory host** | A real request against the app hosted in-process | The feature *is* the request-to-persistence round trip, or you want routing, model binding, validation, auth, and middleware included |

Entering higher up buys **refactor resilience**: a test that posts a request and asserts the response plus
the resulting rows doesn't know whether the code behind it uses a mediator, a service class, an ORM, or raw
SQL — so all of that can be restructured without touching a test. Tests coupled to internal layers punish
refactoring; tests coupled to observable behavior enable it.

That's not free. Higher entry means slower tests, coarser failure messages (a 400 tells you *something*
rejected the request, not which rule), and auth/middleware to satisfy in setup. So: enter at HTTP for the
feature's contract — happy path plus the important failure paths — and unit test the interesting rules
underneath directly. Don't drive a rule matrix through HTTP.

## Decision table

| Harness | Use when | Isolation mechanism |
|---|---|---|
| **EF + real database + fixtures** | The logic under test is C#/EF (services, repositories, business rules) | Disposable/dedicated database, or exact run-owned seeding and teardown |
| **In-memory host + real database** | Testing a feature end to end through its HTTP entrance | Same as above, plus per-test reset of run-owned state |
| **Raw-SQL transaction rollback** | The logic under test is *only* SQL (triggers, computed columns, constraints) with no C#/EF path | One transaction per test, always rolled back, never committed |
| **Legacy T-SQL harness** | Stored procedures/functions with no EF code path, exercised as scripts | See [`../legacy-tsql-harness.md`](../legacy-tsql-harness.md) |

## EF + real database + fixtures

The default for anything with a C# code path. Use a real `DbContext` against the real provider, preferably
with a disposable database or one dedicated to automated tests, so constraints, computed columns, triggers,
and query translation behave as in production without risking unrelated data.

Cost: you own seeding and cleanup explicitly. See [`fixtures.md`](fixtures.md),
[`seeding-and-ids.md`](seeding-and-ids.md), and [`cleanup-and-isolation.md`](cleanup-and-isolation.md).

**Disqualifier:** a shared persistent database without explicit user approval, an exact server/database
allowlist, unique run ownership, and exact cleanup. Do not proceed until those controls exist.

## In-memory host + real database

The app hosted in-process (in .NET, `WebApplicationFactory<Program>`), tests issuing real HTTP requests
through a client. One test covers routing, model binding, validation, auth, the handler, and persistence —
the defect classes a service-level test can't see at all.

Two mechanics that decide whether these tests are honest:

- **Read back through a fresh scope.** Asserting through the same context the request used shows you the
  ORM's change tracker, not the database. A fresh scope proves the row actually persisted, with
  database-computed columns and all.
- **Filter by an identifier the test supplied**, never "the single row in the table". A test that assumes
  it's the only writer breaks the moment it isn't, and the failure looks unrelated.

Assert **both halves of the contract**: the response *and* the resulting state. A rejected request should
also be shown to have written nothing — a 400 with a row quietly inserted anyway is exactly the bug this
harness exists to catch.

Infrastructure (the host, and a container if one is used) starts **once per class**; seeded data still
resets **per test** — see [`fixtures.md`](fixtures.md).

**Disqualifiers:**
- Driving a rule matrix (every branch of a validation or pricing rule) through HTTP. Slow, and the failure
  message names the endpoint rather than the rule. Extract the rule and unit test it.
- Logic with no HTTP entrance. Use the service-level harness.

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

One project can use all four; pick per test class, not per project. Keep them in separate folders and base
classes so the isolation model is obvious from the file you're reading.
