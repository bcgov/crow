# .NET 10+ application diagnostics

Load with [`../application-diagnostics.md`](../application-diagnostics.md). For .NET 10+, use built-in behavior before adding code. Logging scopes and diagnostics vary by host, formatter, and sink; verify the deployed sink rather than assuming local defaults.

## Already handled by .NET 10; do not re-implement

| Generic requirement | Built-in behavior | Your only job |
| --- | --- | --- |
| Request correlation in application logs | ASP.NET Core request hosting provides a scope with `TraceId`, `SpanId`, `ParentId`, `RequestId`, and `RequestPath` | Include scopes in the formatter (`Logging:Console:FormatterOptions:IncludeScopes = true` or `AddJsonConsole(o => o.IncludeScopes = true)`) or sink; verify the fields are queryable in the deployed sink |
| Reference in API errors | The default writer adds `traceId` from `Activity.Id` or, without an activity, `HttpContext.TraceIdentifier` | For a W3C-only `traceId`, replace or remove the default value as below |
| Unhandled exceptions → safe 500 Problem Details | `AddProblemDetails()` + `UseExceptionHandler()` | Register both |
| Exception → status code | `ExceptionHandlerOptions.StatusCodeSelector` | Map known types here or in your `IExceptionHandler` |
| Non-exception error statuses get a body | `UseStatusCodePages()` writes Problem Details when `AddProblemDetails()` is registered | Register it |
| Minimal API validation errors | `AddValidation()` returns `ValidationProblemDetails` | Register it; do not hand-roll validation responses |
| Log the exception once | Exception handler middleware logs unhandled exceptions; when an `IExceptionHandler` returns `true`, .NET 10 **suppresses** the middleware's log, EventSource event, and `error.type` metric tag | Log in your `IExceptionHandler` when it handles the exception. Leave `SuppressDiagnosticsCallback` at its default |
| Stack and inner-exception chain | `ILogger.LogError(exception, ...)` writes `exception.ToString()` (full stack + inner chain) | Always pass the exception object, not `ex.Message` |
| Exception responses not cached | Exception handler middleware sets `Cache-Control: no-cache,no-store` | Set `Cache-Control: no-store` separately for non-exception error responses (including validation, 403, and 404); verify both paths |
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
    var naming = ctx.HttpContext.RequestServices
        .GetRequiredService<IOptions<Microsoft.AspNetCore.Http.Json.JsonOptions>>()
        .Value.SerializerOptions.PropertyNamingPolicy;
    var traceIdKey = naming?.ConvertName("traceId") ?? "traceId";
    if (Activity.Current is { } activity)
        ctx.ProblemDetails.Extensions[traceIdKey] = activity.TraceId.ToString();
    else
    {
        ctx.ProblemDetails.Extensions.Remove(traceIdKey);
        ctx.ProblemDetails.Extensions[naming?.ConvertName("requestId") ?? "requestId"] =
            ctx.HttpContext.TraceIdentifier;
    }
    ctx.ProblemDetails.Extensions["timestamp"] = DateTimeOffset.UtcNow;
});
```

The default writer populates `traceId` before this callback using the configured JSON property naming policy; remove that same key when falling back to a request ID. If existing responses and support lookup use `HttpContext.TraceIdentifier`, retain it as the user-facing `requestId` even when an activity exists; log `TraceId` separately and verify the cross-service join.

### Error catalog via `IExceptionHandler`

- One `IExceptionHandler` maps known exception types to catalog entries `{ status, code, userMessageKey, retryable }`, resolves text through `IStringLocalizer`, and writes through `IProblemDetailsService.TryWriteAsync` with `code` as an extension and `type` as the catalog's stable docs URI. Log once with business context only if the handler writes the response.
- Unknown exceptions use the generic catalog entry (500). Never put `exception.Message` or `GetType().Name` in `title`, `detail`, or `type`.
- Return the result of `TryWriteAsync`. It returns `false` when the client does not accept JSON; leave logging to exception handler middleware on fall-through to the HTML error page.

### Error page (MVC, Razor Pages, Blazor Web App)

- Use `UseExceptionHandler("/Error")`. For Blazor 404s, prefer `NavigationManager.NotFound()` and the Router `NotFoundPage`. If using `UseStatusCodePagesWithReExecute` for empty error responses, dispatch by status (including 401, 403, 404, and 5xx); it re-executes for all bodyless 4xx/5xx responses, not just 404s.
- Replace the template `Error` page: remove "Development Mode" text; show the catalog message, next step, contact, UTC time, and a copyable reference matching the response and logs.
- For in-page failures in Blazor, use `ErrorBoundary` around the affected region with a persistent alert; reset it on retry.

### Business context

Use `ILogger.BeginScope` for operation logs. Preserve safe operation name and entity IDs in request context or the exception so the exception handler can start its own scope after inner scopes unwind. Verify fields in the deployed sink; use message templates, not interpolated strings.

### Exceptions

`throw;` to rethrow; `throw new XException("Failed to load permit {id}", inner)` to wrap.

## Secrets and the escape hatch in .NET

Stand-ins: extract only allowlisted `DataSource` and `InitialCatalog` values from `SqlConnectionStringBuilder` (never log the builder), validated claims from `ClaimsPrincipal` or the JWT bearer `OnAuthenticationFailed` exception (never the raw token), `X509Certificate2.Thumbprint`, and configuration key names via `IConfiguration` providers.

Keep runtime URI redaction enabled. Process-wide switches such as `DOTNET_SYSTEM_NET_HTTP_DISABLEURIREDACTION` and broad EF Core sensitive-data or HTTP header logging cannot enforce expiry and restricted-sink isolation per event; do not use them as the generic escape hatch. Where policy permits exceptional diagnostics, check enabled scope and `ExpiresUtc` via `IOptionsMonitor<T>` on each application-controlled write, using a dedicated `ILogger` category routed only to the restricted sink.
