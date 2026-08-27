# ASP.NET Core development

## Startup and middleware

- Keep environment-specific developer diagnostics inside an explicit development guard.
- Use centralized exception handling and RFC 9457 Problem Details. Log the exception once and return no internal detail.
- Configure forwarded headers only for known proxies/networks and run the middleware before HTTPS/auth decisions.
- Use HTTPS redirection and HSTS in production where TLS terminates compatibly with the platform.
- Add security headers centrally. Build a restrictive CSP from actual resource needs; do not normalize `unsafe-inline` or `unsafe-eval`.
- Order rate limiting, authentication, and authorization before endpoint execution.

## Endpoints and contracts

- Use explicit HTTP verbs and route templates.
- Apply `[ApiController]` for controller APIs or equivalent endpoint filters for minimal APIs.
- Use dedicated request/response models and bounded collections, body sizes, uploads, pagination, and query complexity.
- Return Problem Details/ValidationProblemDetails consistently.
- For externally consumed APIs, implement the documented compatibility/deprecation policy and versioned OpenAPI. Prefer maintained `Asp.Versioning` packages when framework support beyond a simple route convention is required.
- Keep OpenAPI enabled only in approved environments or behind authorization/configuration.
- Do not catch `Exception` in every action. Let the centralized handler process unexpected failures; catch only when the action can add correct recovery or contract semantics.

## Authentication and authorization

- Prefer OIDC/OAuth standards and framework handlers over custom token parsing.
- Configure issuer, audience, lifetime, signing keys, HTTPS metadata, and allowed algorithms explicitly for bearer tokens.
- Use policy-based authorization and resource/ownership checks. An authenticated user is not automatically authorized for an object identifier.
- Prefer a fallback authorization policy for private apps. Mark public endpoints with explicit anonymous metadata.
- When multiple schemes exist, specify which endpoints accept cookie, bearer, or application-token identities.
- Compare security tokens in constant time, store only protected hashes, support expiry/revocation/rotation, and never log raw tokens.

## Browser and API security

- Cookie-authenticated state changes require antiforgery protection and explicit write verbs.
- APIs using bearer credentials normally do not use antiforgery; document the separation instead of broadly disabling protection without context.
- Configure cookies with `HttpOnly`, `Secure`, appropriate `SameSite`, bounded lifetime, and intentional path/domain.
- Use named CORS policies with exact origins. Reject missing production origin configuration at startup.
- Rate-limit authentication, write, upload, search, and expensive endpoints based on abuse risk. Load-test the selected limits.

## Data Protection and replicas

- Persist Data Protection keys to a protected shared location when multiple replicas must read the same cookies or antiforgery tokens.
- Use a stable application name and protect the key ring at rest and in access policy.
- Do not store unnecessary OIDC access/refresh tokens in authentication cookies.

## Outbound HTTP

- Use typed clients and fixed/configured base addresses.
- Do not pass user-controlled absolute URLs to `HttpClient`.
- Validate redirects, disable automatic redirect following when the trust boundary requires it, and prevent access to loopback/link-local/private destinations for user-influenced URLs.

## Required Crow security modules

For endpoint work, load `auth-and-access-control.md`, `framework-security-config.md`, and `api-and-session-security.md`. Add `data-flow-sinks.md` for any SQL/file/process/redirect/outbound HTTP flow.

## Sources

- Microsoft Learn, [ASP.NET Core security topics](https://learn.microsoft.com/aspnet/core/security/)
- Microsoft Learn, [Authorization in ASP.NET Core](https://learn.microsoft.com/aspnet/core/security/authorization/introduction)
- Microsoft Learn, [Prevent Cross-Site Request Forgery](https://learn.microsoft.com/aspnet/core/security/anti-request-forgery)
- Microsoft Learn, [Rate limiting middleware](https://learn.microsoft.com/aspnet/core/performance/rate-limit)
- RFC Editor, [RFC 9457: Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457)
