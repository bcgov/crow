# Integration test fixtures

Load when writing or reviewing a fixture for a database-backed integration test.

## What a fixture owns

A fixture is the "given" of a scenario, extracted so tests only express the "when" and "then". It owns:

- **ID allocation** for every entity it seeds (see [`seeding-and-ids.md`](seeding-and-ids.md)).
- **Failure-safe cleanup of its exact run-owned footprint** (see
  [`cleanup-and-isolation.md`](cleanup-and-isolation.md)).
- **Fail-closed environment verification before mutation** (see
  [`environment-and-diagnostics.md`](environment-and-diagnostics.md)).
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
    public string RunId { get; } = Convert.ToHexString(RandomNumberGenerator.GetBytes(12));

    public async Task InitializeAsync()
    {
        Context    = CreateContext();
        await AssertAllowedDatabaseAsync(Context);
        CustomerId = TestDataConventions.NextCandidateId();
        OrderId    = TestDataConventions.NextCandidateId();

        await new CustomerTestDataBuilder(Context).CreateAsync(CustomerId, RunId);
        await new OrderTestDataBuilder(Context).CreateAsync(
            OrderId, CustomerId, RunId, status: OrderStatus.Open,
            configure: o => o.AssignedToId = AgentId);        // per-scenario tweaks via callback
    }

    public async Task DisposeAsync()
    {
        try { await PurgeAsync(); }
        finally { await Context.DisposeAsync(); }
    }

    public OrderService CreateService(Roles role = Roles.None) => new(
        new UnitOfWork(Context, LoggerFactory, new CurrentUser { Id = 1, Role = role }),
        Mock.Of<ISearchIndexService>(),      // external system: mocked
        Mock.Of<INotificationService>());    // external system: mocked
}
```

Give the fixture a `CreateService(...)` factory rather than exposing raw dependencies — tests that need a
different role or user then differ by one argument instead of rebuilding the whole graph.

## Fixture lifetime: the important decision

Test frameworks offer a *class-shared* fixture (xUnit's `IClassFixture<T>`: constructed once, reused by
every test in the class) and a *per-test* fixture (the test class implements the async lifetime interface
and constructs its own, so new-instance-per-test gives each test a fresh one).

**Default to per-test.** A class-shared fixture means every test shares one seeded entity graph *and one
`DbContext`*, producing hard-to-diagnose failures: mutations change later tests' starting conditions so
results depend on order; the shared change tracker hands a later test a stale or partially-modified entity
instead of what's persisted; and one mid-class failure cascades into misleading failures after it.

```csharp
public class OrderStateTransitionTests : IAsyncLifetime      // NOT IClassFixture<T>
{
    private readonly OrderAssignmentFixture _fixture = new();

    public Task InitializeAsync() => _fixture.InitializeAsync();
    public Task DisposeAsync()    => _fixture.DisposeAsync();
}
```

Reach for a class-shared fixture only when setup is genuinely expensive *and* every test in the class is
strictly read-only against it. If you do, say so in a comment — the next person will assume per-test.

**Separate the two lifetimes rather than compromising between them.** Expensive *infrastructure* — an
in-process host, a database container, a connection — can safely start once per class, because it holds no
test-specific state. *Seeded data* still resets per test. Where infrastructure is class-shared, reset seeded state per test. A disposable or dedicated database may
clear feature tables; an approved shared database must delete only the exact keys and run markers owned by
the completed test. This keeps startup cost amortized without reintroducing order-dependent tests or
touching unrelated data.

Whichever you choose, **create a fresh `DbContext` per fixture instance**, mirroring the request-scoped
lifetime a context has in production.

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
