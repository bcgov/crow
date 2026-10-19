# .NET 10+ application diagnostics

Load with [`../application-diagnostics.md`](../application-diagnostics.md). For .NET 10+, use built-in behavior before adding code.

## Already handled by .NET 10; do not re-implement

| Generic requirement | Built-in behavior | Your only job |
| --- | --- | --- |
| Support reference on every log line | Hosting creates a request logging scope with `TraceId`, `SpanId`, `ParentId`, `RequestId`, and `RequestPath` | Turn scopes on in the formatter (`Logging:Console:FormatterOptions:IncludeScopes = true`, or `AddJsonConsole(o => o.IncludeScopes = true)`) or the configured sink, and verify the fields appear in the deployed sink |
| Reference in API errors | `AddProblemDetails()` adds a `traceId` extension to every Problem Details response | Nothing, unless you want the shorter 32-hex trace ID (see below) |
| Unhandled exceptions → safe 500 Problem Details | `AddProblemDetails()` + `UseExceptionHandler()` | Register both |
| Exception → status code | `ExceptionHandlerOptions.StatusCodeSelector` | Map known types here or in your `IExceptionHandler` |
| Non-exception error statuses get a body | `UseStatusCodePages()` writes Problem Details when `AddProblemDetails()` is registered | Register it |
| Minimal API validation errors | `AddValidation()` returns `ValidationProblemDetails` | Register it; do not hand-roll validation responses |
| Log the exception once | Exception handler middleware logs unhandled exceptions; when an `IExceptionHandler` returns `true`, .NET 10 **suppresses** the middleware's log, EventSource event, and `error.type` metric tag | Log in your `IExceptionHandler` when it handles the exception. Leave `SuppressDiagnosticsCallback` at its default |
| Stack and inner-exception chain | `ILogger.LogError(exception, ...)` writes `exception.ToString()` (full stack + inner chain) | Always pass the exception object, not `ex.Message` |
| Error responses not cached | Exception handler middleware sets `Cache-Control: no-cache,no-store` | Nothing |
| Developer exception page only in development | `WebApplication` enables it only in the Development environment | Do not enable it elsewhere |
| Outbound call start, duration, status | `IHttpClientFactory` logs start/end with elapsed ms and status; `System.Net.Http` emits `Activity` spans and the `http.client.request.duration` metric with `error.type` | Use named/typed clients; add your own events only for business stage context |
| Outbound URL secrets | .NET 9+ redacts query strings (`*`), user info, and fragments in `HttpClient` logs and events | Log query **keys** yourself if needed |
| W3C trace propagation | `HttpClient` sends `traceparent`; ASP.NET Core reads it | Verify in a deployed test across services |
| Readiness vs liveness | `AddHealthChecks()` + `MapHealthChecks` with tag predicates | Tag dependency checks `ready`; keep liveness free of dependencies |
| Blazor not-found | `NavigationManager.NotFound()` and the Router `NotFoundPage` | Use them instead of custom 404 plumbing |

## Additions .NET does not provide

### Shorter user-facing reference

Built-in Problem Details and the template `Error` page show `Activity.Id` (`00-<traceId>-<spanId>-01`). For new contracts, show the shorter `TraceId` (matching log scopes), falling back to a separately labeled request ID when no activity exists:

```csharp
builder.Services.AddProblemDetails(o => o.CustomizeProblemDetails = ctx =>
{
    if (Activity.Current is { } activity)
        ctx.ProblemDetails.Extensions["traceId"] = activity.TraceId.ToString();
    else
        ctx.ProblemDetails.Extensions["requestId"] = ctx.HttpContext.TraceIdentifier;
    ctx.ProblemDetails.Extensions["timestamp"] = DateTimeOffset.UtcNow;
});
```

If existing responses and support lookup use `HttpContext.TraceIdentifier`, retain it as the user-facing `requestId` even when an activity exists; log `TraceId` separately and verify the cross-service join.

### Error catalog via `IExceptionHandler`

- One `IExceptionHandler` maps known exception types to catalog entries `{ status, code, userMessageKey, retryable }`, resolves text through `IStringLocalizer`, logs once with business context, and writes through `IProblemDetailsService.TryWriteAsync` with `code` as an extension and `type` as the catalog's stable docs URI.
- Unknown exceptions use the generic catalog entry (500). Never put `exception.Message` or `GetType().Name` in `title`, `detail`, or `type`.
- Return the result of `TryWriteAsync`. It returns `false` when the client does not accept JSON, so HTML requests fall through to the error page below with the same reference.

### Error page (MVC, Razor Pages, Blazor Web App)

- Use `UseExceptionHandler("/Error")`; for Blazor 404s use `UseStatusCodePagesWithReExecute("/not-found", createScopeForStatusCodePages: true)`.
- Replace the template `Error` page: remove "Development Mode" text; show the catalog message, next step, contact, UTC time, and a copyable reference matching the response and logs.
- For in-page failures in Blazor, use `ErrorBoundary` around the affected region with a persistent alert; reset it on retry.

### Business context

Add one `ILogger.BeginScope` at the operation boundary (handler, service method, or endpoint filter) with operation name and entity IDs, so every line in that operation carries them. Use message templates, not interpolated strings.

### Exceptions

`throw;` to rethrow; `throw new XException("Failed to load permit {id}", inner)` to wrap.

## Secrets and the escape hatch in .NET

Stand-ins: `SqlConnectionStringBuilder` (remove `Password`), validated claims from `ClaimsPrincipal` or the JWT bearer `OnAuthenticationFailed` exception (never the raw token), `X509Certificate2.Thumbprint`, configuration key names via `IConfiguration` providers.

Built-in switches to tie to the time-boxed escape hatch (off by default):

| Need | Switch |
| --- | --- |
| Full outbound URLs with query values | `DOTNET_SYSTEM_NET_HTTP_DISABLEURIREDACTION=true` (process-wide; prefer the environment variable so it is removable without a build) |
| EF Core parameter values | `EnableSensitiveDataLogging()` behind the switch |
| Outbound header values | `IHttpClientFactory` logs headers only at Trace; raise the level for that client's category temporarily, and keep `RedactLoggedHeaders` for `Authorization` and cookies |

Bind the switch with `IOptionsMonitor<T>` (enabled flag + `ExpiresUtc`) so it changes without a deployment, and write sensitive values to a dedicated `ILogger` category routed to the restricted sink.
