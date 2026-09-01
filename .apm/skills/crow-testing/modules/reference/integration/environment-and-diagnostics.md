# Environment and diagnostics

Load when wiring up an integration test project's configuration, or when a failure is opaque and you need
better signal.

## Configuration layering

Integration tests need a real connection string, which must never be committed. Three layers:

| Layer | Committed? | Purpose |
|---|---|---|
| `appsettings.IntegrationTests.json` | Yes | Non-secret defaults, placeholders |
| `appsettings.IntegrationTests.local.json` | **No** — git-ignored | Each developer's own DEV connection string |
| Environment variables | n/a | How CI supplies the connection string |

```csharp
new ConfigurationBuilder()
    .AddJsonFile("appsettings.IntegrationTests.json", optional: false)
    .AddJsonFile("appsettings.IntegrationTests.local.json", optional: true)  // optional: absent in CI
    .AddEnvironmentVariables()
    .Build();
```

Order matters: later sources win, so CI's environment variable overrides any file.

## Fail fast, and name the knob

A missing connection string should fail with a message that tells the reader exactly what to set and where —
not a null-reference or a connection timeout thirty seconds later:

```csharp
if (string.IsNullOrWhiteSpace(connectionString))
    throw new InvalidOperationException(
        "No 'AppDb' connection string configured. Set ConnectionStrings:AppDb in " +
        "appsettings.IntegrationTests.local.json (local dev, git-ignored) or the " +
        "ConnectionStrings__AppDb environment variable (CI).");
```

This is the single highest-value error message in the project: it's what every new developer and every fresh
CI agent hits first.

Integration tests run against DEV, and optionally TEST. **Never UAT or production** — tests seed, mutate,
and delete rows. If it's cheap, assert the target environment on startup rather than trusting configuration.

## Make seeded data recognizable to humans

Reserved IDs (see [`seeding-and-ids.md`](seeding-and-ids.md)) identify test rows *programmatically*. Also tag
them **visibly**, by prefixing a text column that appears in the UI:

- `IntTest-` — rows created by automated integration tests
- `QATest-` — rows created by manual exploratory seeding
- `E2ETest-` — rows created by end-to-end runs

Someone browsing the shared DEV environment can then tell at a glance that a record is test data and where it
came from, instead of filing a bug about it. Use the same prefix scheme across every seeding mechanism.

## Enrich database exceptions

A raw driver exception ("Invalid column name 'foo'") omits everything needed to act on it: which server,
which database, which statement, which parameters. Wrap execution and rethrow with that context attached:

```csharp
catch (SqlException ex)
{
    throw new InvalidOperationException(
        $"SQL {operation} failed on server '{conn.DataSource}', database '{conn.Database}'. " +
        $"Parameters: {parameterNames}. Command: {normalizedSql}. " +
        $"SQL Server errors: {errorDetails}.{missingColumnHint}", ex);
}
```

Worth including:
- **Server and database name** — proves which environment actually ran the statement, which is the first
  thing to doubt when results are surprising.
- **The statement**, whitespace-normalized so it's one readable line.
- **Parameter names** (not values — they may hold sensitive data).
- **Each driver error's number, message, procedure, and line**, so failures inside a stored procedure or
  trigger point at the real location rather than at the calling statement.
- **A parsed hint for common errors.** Extracting the column name from "Invalid column name 'X'" turns a
  schema-drift failure into an immediately actionable one.

Always pass the original exception as the inner exception — never swallow it.

## Route ORM logs to test output

Wire the ORM's logger factory to the test framework's output helper so a failing test shows the SQL it
actually generated. This is often the fastest route from "the assertion failed" to "the query didn't filter
the way I assumed".

Keep it at a level that isn't overwhelming (statements, not verbose internals), and prefer a null logger for
tests where SQL isn't the thing under investigation.
