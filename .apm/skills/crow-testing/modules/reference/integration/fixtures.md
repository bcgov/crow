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

    public async Task InitializeAsync()
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

    public async Task DisposeAsync() => await Context.DisposeAsync();

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

Whichever you choose, **create a fresh `DbContext` per fixture instance**, mirroring the request-scoped
lifetime a context has in production.

## What to mock, and what not to

Draw the line at the **process boundary**. Real: the database, `DbContext`, repositories, unit-of-work, and
the service under test. Mocked: external systems — search indexes, notification senders, third-party HTTP
APIs, message buses.

Over-mocking is the common failure: mock the repository layer and the test proves nothing the unit tests
already did. If you're mocking the `DbContext`, you wanted a unit test — go back to `unit-tests.md`'s
scoping check. State this boundary in the test class's doc comment.
