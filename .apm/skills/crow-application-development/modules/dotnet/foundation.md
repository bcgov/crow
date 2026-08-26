# .NET development foundation

## Language and project defaults

- Target the repository's supported .NET baseline; use .NET 10 or later for new applications unless an approved platform constraint says otherwise.
- Enable nullable reference types and fix warnings through types and guards rather than null-forgiving operators.
- Prefer async APIs end to end for I/O. Pass `CancellationToken` through controllers, services, EF Core, HTTP, and hosted work.
- Use primary constructors, records, collection expressions, and other current language features when they improve clarity and match the repository language version.
- Keep public APIs deliberate. Default implementation types to `internal` or `sealed` when extension is not intended.
- Use `TimeProvider` for testable time and `RandomNumberGenerator` for security-sensitive randomness.

## Dependency injection and lifetime

- Use constructor injection. Do not resolve services from `IServiceProvider` in business code.
- Choose lifetimes by ownership: singleton only for thread-safe shared state, scoped for request/unit-of-work state, transient for lightweight stateless services.
- Never inject scoped services into singletons. Hosted services create an explicit scope for scoped work.
- Register `HttpClient` through `IHttpClientFactory`; configure base address, authentication, timeout, and resilience per external system.

## Configuration and secrets

- Bind related configuration to options and validate it on start.
- Avoid repeated string-key access throughout code.
- Use Secret Manager only for local development and an approved secret store/workload identity in deployed environments.
- Do not put credentials in `appsettings*.json`, launch settings, Docker build arguments, pipeline YAML, or test snapshots.

## Errors and telemetry

- Throw specific exceptions for exceptional conditions; use typed results for expected domain outcomes.
- Handle exceptions once at the delivery boundary and translate them into the established contract.
- Use `ILogger<T>` message templates rather than interpolated strings. Redact values before logging.
- Add metrics/traces around external calls and important operations, but avoid high-cardinality labels such as raw user IDs or URLs.

## Safe concurrency

- Avoid blocking on tasks with `.Result`, `.Wait()`, or `GetAwaiter().GetResult()` in request paths.
- Protect mutable singleton state or replace it with immutable/concurrent structures.
- Do not use fire-and-forget tasks for required work. Queue durable work or await completion.
- Make hosted loops cancellation-aware and isolate per-iteration failures without hiding persistent failure.

## Sources

- Microsoft Learn, [C# coding conventions](https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions)
- Microsoft Learn, [Dependency injection in .NET](https://learn.microsoft.com/dotnet/core/extensions/dependency-injection/overview)
- Microsoft Learn, [Options pattern in .NET](https://learn.microsoft.com/dotnet/core/extensions/options)

