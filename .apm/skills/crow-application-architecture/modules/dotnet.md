# .NET architecture module

Load this module for any modern .NET application. Load `aspnet-core.md` as well for web workloads.

## Runtime and solution baseline

- New applications target a supported LTS or current .NET release approved by the organization. Use .NET 10 as the baseline; do not copy legacy .NET Framework patterns into new work.
- Pin the SDK with `global.json` when build agents and developer machines need deterministic selection.
- Enable nullable reference types and implicit usings. Keep analyzers enabled and centralize shared compiler settings in `Directory.Build.props`.
- Keep one root `.sln` or `.slnx` and predictable `src/` and `tests/` folders.
- Commit package lock files for applications and restore them in locked mode in CI.
- Decide trimming and Native AOT from measured startup, memory, and deployment requirements. Treat trim/AOT warnings as compatibility defects and avoid reflection-heavy designs when AOT is an explicit goal.

## Project boundaries

Use project boundaries to enforce dependency direction, not to mirror every folder.

A useful starting shape is:

```text
src/
  Product.Web/             # HTTP/UI composition root
  Product.Application/     # use cases and application policy, when warranted
  Product.Domain/          # framework-independent rules, when domain complexity warrants
  Product.Infrastructure/  # external-system implementations
tests/
  Product.UnitTests/
  Product.IntegrationTests/
```

Smaller applications may use `Product.Web` plus one class library and matching tests. Add Application, Domain, or Infrastructure projects only when they create an enforceable boundary. 

## Dependency direction

- The executable project is the composition root and references the modules it assembles.
- Domain code references no ASP.NET Core, EF Core, logging sink, or cloud SDK package.
- Application code depends on abstractions it owns when it needs external capabilities.
- Infrastructure implements those abstractions and is wired by the composition root.
- Shared contracts contain stable boundary types only. Avoid a general-purpose `Common` project.
- Register related services through focused extension methods once `Program.cs` becomes difficult to scan; keep the registration behavior explicit.

## Hosting and background work

- Use the Generic Host for web apps, workers, and long-running services so configuration, DI, logging, lifetime, and health behavior are consistent.
- Use `BackgroundService`/`IHostedService` for host-coupled work. Create scopes for scoped dependencies and honor the stopping token.
- Move durable or independently scalable work to a queue-backed worker; design idempotency and poison-message handling before deployment.
- Use typed or named `HttpClient` instances through `IHttpClientFactory`; define timeouts and resilience deliberately rather than creating clients ad hoc.
- Prefer `Microsoft.Extensions.Resilience` and `Microsoft.Extensions.Http.Resilience` (Polly v8) over ad hoc policies or the deprecated `Microsoft.Extensions.Http.Polly`; design retries only for transient, safe operations.
- For multi-service .NET systems, evaluate .NET Aspire service defaults and local orchestration rather than hand-building service discovery, OpenTelemetry, health, and resilience wiring. Do not introduce it to a single service without a concrete benefit.

## Configuration

- Bind cohesive settings to options classes and validate them at startup.
- Use environment-specific configuration only for non-secret differences. Supply secrets through a secret manager or workload identity.
- Reject missing issuer, audience, allowed origins, encryption keys, or external endpoints outside development/test.
- Keep local developer defaults visibly non-production and impossible to deploy accidentally.
- Keep globalization data available. Do not trade away ICU/culture behavior through invariant globalization or minimal image selection when the application handles Indigenous-language or other culture-sensitive text.

## Persistence boundary

Data architecture is excluded, but application boundaries still apply:

- Keep transaction ownership at the use-case boundary.
- Do not expose provider-specific query objects across application boundaries.
- Avoid a generic repository over EF Core when it only hides useful features without adding policy.
- Place migrations and provider configuration with the owning application/infrastructure module and deploy them through a controlled release step.

## Sources

- Microsoft Learn, [Architectural principles](https://learn.microsoft.com/dotnet/architecture/modern-web-apps-azure/architectural-principles)
- Microsoft Learn, [Dependency injection in .NET](https://learn.microsoft.com/dotnet/core/extensions/dependency-injection/overview)
- Microsoft Learn, [Options pattern in .NET](https://learn.microsoft.com/dotnet/core/extensions/options)
- Microsoft Learn, [Introduction to resilient app development](https://learn.microsoft.com/dotnet/core/resilience/)
- Microsoft Learn, [ASP.NET Core support for Native AOT](https://learn.microsoft.com/aspnet/core/fundamentals/native-aot)
