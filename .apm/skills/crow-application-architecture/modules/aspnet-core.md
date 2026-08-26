# ASP.NET Core architecture module

Load this module only for HTTP APIs, MVC, Razor Pages, Blazor, or ASP.NET Core-hosted SPAs.

## Composition and middleware

- Keep `Program.cs` as the visible composition root. Group registration in cohesive extension methods, but do not hide ordering-sensitive middleware.
- Put forwarded-header handling first when running behind a trusted proxy. Configure known networks/proxies explicitly; never clear trust lists merely to make redirects work.
- Place exception handling and security headers before endpoint execution.
- Place routing before rate limiting, authentication, and authorization when endpoint metadata drives those policies.
- Map health endpoints intentionally and keep probe exposure minimal.
- Gate OpenAPI and developer diagnostics by environment or an explicit secure configuration.

## API and UI boundaries

- Use controllers, minimal APIs, Razor, or Blazor consistently within a bounded surface; choose based on application needs rather than novelty.
- Use request/response contracts instead of exposing persistence entities.
- Return RFC 7807 Problem Details for API failures and validation errors. Do not leak exception messages or stack traces.
- Version externally consumed APIs and define compatibility/deprecation policy.
- Keep SPA build/runtime concerns isolated from the API. If independently deployable evolution is likely, avoid coupling the SPA build into the API publish artifact.

## Identity and access

- Prefer standards-based OIDC/OAuth integration. Use policy-based authorization for business permissions and resource-based checks for ownership.
- Adopt a fallback authorization policy for private applications so new endpoints deny anonymous access unless explicitly allowed.
- Separate authentication schemes deliberately when browser cookies and bearer/PAT access coexist.
- Persist ASP.NET Core Data Protection keys in a protected shared store when replicas must validate the same cookies or antiforgery tokens.

## Operational design

- Define separate liveness and readiness endpoints and protect any diagnostic detail.
- Apply rate limits according to abuse and resource-cost boundaries, not one arbitrary global number.
- Treat reverse-proxy configuration, cookie security, HTTPS metadata, CORS, CSP, and Data Protection as one coherent deployment design.
- Use OpenTelemetry-compatible logs, metrics, and traces. Ensure user identifiers and request bodies are not captured without an approved need, and all sensitive or personal information is kept out of logs.

## Security acceptance

Before implementation starts, load the relevant `crow-security-review` modules named in the parent skill. The design must explicitly cover:

- default authentication/authorization behavior;
- resource ownership checks that prevent IDOR;
- antiforgery for cookie-authenticated state changes;
- CORS allowlists and secure cookies;
- request/body/upload limits and rate limiting;
- safe outbound HTTP and redirect policies;
- secret storage, TLS, headers, and production error behavior.

## Sources

- Microsoft Learn, [ASP.NET Core security topics](https://learn.microsoft.com/aspnet/core/security/)
- Microsoft Learn, [Rate limiting middleware in ASP.NET Core](https://learn.microsoft.com/aspnet/core/performance/rate-limit)
- Microsoft Learn, [Health checks in ASP.NET Core](https://learn.microsoft.com/aspnet/core/host-and-deploy/health-checks)
- Microsoft Learn, [Overview of OpenTelemetry](https://learn.microsoft.com/dotnet/core/diagnostics/observability-with-otel)

