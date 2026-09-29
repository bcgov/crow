# Integration test fixtures

Load when writing or reviewing a fixture for a database-backed integration test.

## What a fixture owns

A fixture is the "given" of a scenario, extracted so tests only express the "when" and "then". It owns:

- **ID allocation** for every entity it seeds (see [`seeding-and-ids.md`](seeding-and-ids.md)).
- **Cleanup of its own footprint before seeding** (see
  [`cleanup-and-isolation.md`](cleanup-and-isolation.md)).
- **Seeding a coherent starting state** — several related entities in the shape a real scenario requires,
  not one row at a time.
- **Exposing the seeded IDs as properties** (`CustomerId`, `OrderId`, `AgentId`) so tests reference them by
  name instead of re-querying or hardcoding.
- **Constructing the service under test** with its real dependencies wired up.

```csharp
public sealed class OrderAssignmentFixture : IntegrationTestBase, IAsyncLifetime
{
    public MyDbContext Context { get; private set; } = null!;
    public int CustomerId { get; private set; }
    public int OrderId { get; private set; }

    public async ValueTask InitializeAsync()
    {
        Context    = CreateContext();
        CustomerId = TestDataConventions.NextNegativeId();
        OrderId    = TestDataConventions.NextNegativeId();

        await PurgeAsync();                                  // self-healing: clear prior residue first

        await new CustomerTestDataBuilder(Context).CreateAsync(CustomerId);
        await new OrderTestDataBuilder(Context).CreateAsync(
            OrderId, CustomerId, status: OrderStatus.Open,
            configure: o => o.AssignedToId = AgentId);        // per-scenario tweaks via callback
    }

    public async ValueTask DisposeAsync() => await Context.DisposeAsync();

    public OrderService CreateService(Roles role = Roles.None) => new(
        new UnitOfWork(Context, LoggerFactory, new CurrentUser { Id = 1, Role = role }),
        Mock.Of<ISearchIndexService>(),      // external system: mocked
        Mock.Of<INotificationService>());    // external system: mocked
}
```

`InitializeAsync` / `DisposeAsync` return `ValueTask` — that's the xUnit.v3 signature. On xUnit v2 the same
methods return `Task`; the pattern is otherwise identical. Crow's default is v3 — see the v2→v3 assessment
in [`../xunit-v2-to-v3-migration.md`](../xunit-v2-to-v3-migration.md) if the target project is still on v2.

Give the fixture a `CreateService(...)` factory rather than exposing raw dependencies — tests that need a
different role or user then differ by one argument instead of rebuilding the whole graph.

## Fixture lifetime: the important decision

Test frameworks offer a *class-shared* fixture (xUnit's `IClassFixture<T>`: constructed once, reused by
every test in the class) and a *per-test* fixture (the test class implements the async lifetime interface
and constructs its own, so new-instance-per-test gives each test a fresh one).

**Default to per-test.** A class-shared fixture that shares one seeded entity graph *and one `DbContext`*
means mutations change later tests' starting conditions, results depend on order, and the shared change
tracker can hand a later test stale or partially modified state.

```csharp
public class OrderStateTransitionTests : IAsyncLifetime      // NOT IClassFixture<T>
{
    private readonly OrderAssignmentFixture _fixture = new();

    public ValueTask InitializeAsync() => _fixture.InitializeAsync();
    public ValueTask DisposeAsync()    => _fixture.DisposeAsync();
}
```

### Exception: expensive stable SQL Server baseline

When the baseline graph is expensive to create and remains unchanged across the class, a class-shared
fixture may seed that baseline once, **outside** the per-test transactions. This is not permission to
share a mutable context. For each test:

1. Create a fresh `DbContext` and begin one database transaction.
2. Execute all test-specific setup, the system behavior, and verification through that context/transaction.
   If the system creates its own context or connection, explicitly propagate the shared connection and
   transaction (for example with `Database.UseTransaction(...)`) and verify that the system under test
   actually enlists in the same boundary.
3. Have builders and helpers reuse the existing transaction; they must not open nested transactions.
4. In `DisposeAsync`, attempt rollback regardless of test outcome, explicitly dispose the transaction, and
   dispose the context afterward. Preserve/report both the original test failure and any rollback or
   disposal failure using the test framework's supported failure mechanism; never turn cleanup failure into
   a passing test.

If rollback fails, immediately stop using that context, close and dispose its connection/session in a
`finally` path, and report the failure. Verify fixture-owned residue and blocking locks where practical;
do not begin another shared-database test until recovery is complete. The fixture must document its
operator/CI recovery path: identify the owned rows by its marker or reserved range, clear them in
dependency order, confirm the session is gone and locks are released, and fail the run if recovery cannot
be verified. A rollback failure is not permission to preserve failed data for later diagnosis.

Example verification queries for the recovery path (adapt table/marker names to the fixture):

```sql
-- Confirm the failed session is gone (replace @@SPID literal with the fixture's captured session_id)
SELECT session_id FROM sys.dm_exec_sessions WHERE session_id = @FailedSessionId;

-- Confirm no locks remain held by that session
SELECT request_session_id, resource_type, request_mode
FROM sys.dm_tran_locks WHERE request_session_id = @FailedSessionId;

-- Confirm no fixture-owned residue remains (use the fixture's reserved-ID range or marker column)
SELECT COUNT(*) FROM dbo.{table} WHERE {pk} < 0 AND {fixture_marker_predicate};
```

Recovery is verified only when the session query returns no row, the lock query returns no row, and every
residue query returns zero. If any check cannot be run in the target environment, treat recovery as
unverified and fail the run rather than assuming success.

The test class must remain sequential when it uses a shared database. Keep the existing
`DisableTestParallelization` decision explicit at the test-assembly/collection boundary, and account for
other classes and independently running test processes that can still touch the same database. Do not
trade correctness for elapsed time.

The fixture also needs cross-process isolation for its committed baseline. Use an exclusive lock/lease,
an isolated database/schema, or another project-supported run boundary. If another developer, CI job, or
test process can purge or reseed the same baseline concurrently and no such boundary exists, use the
default per-test fixture instead.

Use this exception only when all test mutations can participate in the same transaction. If a dependency
commits independently, uses another connection that must observe the data, or otherwise cannot enlist,
use the default per-test fixture and explicit cleanup instead.

An ordinary `WebApplicationFactory` request test is disqualified unless transaction propagation into the
request-scoped application context is deliberately configured and verified. A test-created transaction
does not automatically include a context created by the hosted application.

The committed baseline requires its own idempotent lifecycle: purge the fixture-owned footprint before
seeding, seed only after that purge succeeds, and remove or reset the baseline at the class/run boundary
according to the fixture's retention decision. Use a unique fixture marker or reserved ownership range,
include trigger-, audit-, and service-created tables, and document recovery for partial seeding or process
termination. If the baseline is intentionally retained, document why, keep it immutable or resettable,
and verify ownership before reuse. Baseline cleanup remains required even though per-test mutations roll
back.

#### Decision checklist

This checklist is a subset for a quick first pass. Selecting the exception requires satisfying every
requirement above in full, not only the items below.

- Is the baseline expensive and unchanged across tests?
- Can all test setup and system mutations use one transaction?
- Do builders reuse an existing transaction rather than opening nested transactions?
- Is cleanup still required for committed baseline data?
- Does the fixture document which tables must be added to explicit cleanup?
- Is the system under test's own transaction/connection enlistment verified, and — for a hosted
  (`WebApplicationFactory`) request test — is that propagation deliberately configured and verified?
- Are shared-database sequential execution and cross-process isolation (lock/lease or isolated
  database/schema) both in place?
- Is a rollback-failure residue/lock recovery path defined, documented, and verified?

Do not choose this pattern from a fixed test-count rule such as “more than three tests.” Baseline
stability and transaction compatibility determine the decision.

#### Rollback and observability

- **CI/CD:** always use rollback isolation for test mutations. Do not preserve failed rows in the shared
  DEV/TEST database; residue and open SQL locks create more risk than diagnostic value.
- **Developer workstation:** also use rollback isolation. Add breakpoints and inspect the active test
  `DbContext` and its open transaction while the test is paused when data inspection is needed.
- **Post-run diagnosis:** use test output and targeted logging rather than preserving failed database data.
- A successful test rolls back all of its mutations.
- A failed test's mutations are also rolled back during `DisposeAsync` when the transaction is still
  usable; rollback and disposal failures must remain visible rather than masking the original failure.
  A rollback failure requires the residue/lock recovery path above.
- After the run, the failed test's uncommitted rows generally cannot be inspected in SSMS or another
  database session.
- While paused in a debugger, the data exists inside the open test transaction and can be queried through
  that same connection/context. Other database sessions usually cannot see it because it is uncommitted.
- A committed fixture baseline remains visible because it was seeded outside the per-test transaction.

Rollback improves isolation and makes cleanup happen automatically and earlier, but removes post-run
forensic data. The old cleanup-based fixtures already deleted test data during disposal; rollback changes
the timing and reliability of that cleanup rather than introducing an entirely new trade-off.

**Separate the two lifetimes rather than compromising between them.** Expensive *infrastructure* — an
in-process host, a database container, a connection — can safely start once per class, because it holds no
test-specific state. *Seeded data* still resets per test. Where infrastructure is class-shared, give the
fixture a `ResetAsync()` that clears the tables the feature touches and call it at the start of each test;
that keeps startup cost amortized without reintroducing order-dependent tests. This is why "start the
container once per class" and "give every test a clean slate" are not in conflict.

For the default pattern, create a fresh `DbContext` per fixture instance, mirroring the request-scoped
lifetime a context has in production. For the exception above, create a fresh context per test and never
retain it on the class-shared fixture.

## What to mock, and what not to

Draw the line at **ownership, not distance**. The database is in another process and still stays real,
because your team controls its schema, its constraints, and when it changes. What you don't own is what you
can't control and shouldn't depend on in a test — payment gateways, email and notification providers,
search indexes, third-party HTTP APIs, message brokers.

**Fake only what you don't own.** Faking something you own means the test can no longer catch broken SQL, a
bad mapping, a violated constraint, or a query that translates differently than you assumed — which is most
of what an integration test exists for.

Over-mocking is the common failure: mock the repository layer and the test proves nothing the unit tests
already did. If you're mocking the `DbContext`, you wanted a unit test — go back to `unit-tests.md`'s
scoping check. State this boundary in the test class's doc comment.
