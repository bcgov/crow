# Application diagnostics: error handling and logging

Goal: show the user something **generic with simple actionable guidance** and a support reference, while logging **detailed, restricted evidence** that lets a developer or operator diagnose the failure quickly.

Scope: error handling and incident diagnosis for user-facing applications; the user-facing contract is technology-neutral, with .NET and Java host notes below. Security-event auditing (authentication, authorization, privilege and credential changes) stays in [`security-logging-and-audit.md`](../../crow-security-review/modules/security-logging-and-audit.md); reuse its privacy rules, do not duplicate them. Error-page presentation, focus, and announcements follow the B.C. UX accessibility guidance when a UX skill is available. Examples are synthetic.

## Required diagnostic outcome

For a reproducible failure that reaches the UI, the user can copy:

- an opaque, unique **support reference**;
- UTC time;
- an understandable explanation and next step;
- the application-approved contact channel.

An authorized operator can use that reference to find one error/outcome event with: exception stack and inner cause *when an exception exists*, failure stage, status (or explicitly no status), elapsed time, identity context when authorized, and a trace joining the initiating host to its dependencies.

- If no response reaches the UI, never claim the user received a server-issued reference. Offer a client-side attempt reference if supported, otherwise ask for time and task.
- A silent or stuck call must leave a start event and an independent latency/readiness signal; logging alone cannot diagnose a hung process.

## Identifiers

| ID | Rule |
| --- | --- |
| `supportId` | New, opaque, unpredictable. Assigned **before** a user-visible operation awaits a dependency; carried in start and boundary events; shown when an error reaches the user. Never encode account, session, or topology. A downstream service's own reference may differ; link via verified trace. Treat any browser-generated attempt reference as untrusted input, never authorization. |
| `traceId`/`spanId` | W3C trace context across real outbound and inbound calls, **verified in a deployed test**. Host `requestId` is local and not proof of propagation; log it alongside, and label missing propagation as missing. |
| `callId` | Shared by the pre-await start and terminal events of one external operation. Retries are distinct attempts. Distinguishes simultaneous calls in one request. |

## Operator event fields

Use structured, stable fields: event name, UTC timestamp, service/environment/release, `supportId` where issued, trace/span/request/call IDs where available, operation and stage, dependency, **actual outbound method and route template (or redacted resolved path)**, outcome, duration ms, response status if received, stable upstream error code if safe, reason category, exception type, and restricted exception record when applicable.

- Keep high-cardinality values in logs, not metric labels.
- Record initiating actor and affected subject separately for privileged operations; never invent a user ID before authentication.
- Use the repository's existing logger templates; no string-concatenated messages.

## External-call lifecycle

1. Emit a start event **before** the await.
2. Emit exactly one classified terminal outcome when control resumes (result, exception, or cancellation).
3. Log the exception stack **once**, at the delivery boundary. Terminal operation events reference the `callId` without repeating the stack.
4. Record elapsed time even when no HTTP response exists. Never manufacture a status for a connection failure.
5. Classify DNS, TLS, socket, deadline, client cancellation, provider denial, invalid response, and downstream 4xx/5xx **only when evidence supports it**. Preserve transport exception types and inner causes in restricted logs. Record stable failure code and permitted validation detail so distinct 400s from one method differ.
6. A start with no terminal event is an in-flight investigation lead, not proof of root cause.

## User-facing versus operator evidence

Raw exception messages, referrer URLs, user GUIDs, and session IDs can contain tokens, authorization codes, SQL parameters, or private data, and a session ID can itself be a credential. Default as below; never silently drop a stakeholder request, present the need and this default.

| Information | User-facing response (page / toast / Problem Details) | Restricted operator log |
| --- | --- | --- |
| Identifier | Copyable `supportId` | Same `supportId`, joined to `traceId`, `requestId`, `callId` |
| Date/time | Labeled UTC date and time | ISO 8601 UTC plus monotonic elapsed duration; identify clock-skew issues |
| User ID/GUID | Normally none; if approved, the user's own intentionally public reference | Verified actor/workload ID; separate impersonation initiator and target; classify retention/privacy |
| Session ID | Never expose auth session ID or cookie; an approved independent support-session reference only if needed | Never raw session secrets; keep support-session lifetime/scope explicit; absence before sign-in is normal |
| `Exception.Message` | Vetted, localized, actionable text for known conditions; generic text otherwise; never the raw message | Type, stack, inner chain, and vetted/redacted cause once at the boundary; keep the meaning, not any secret |
| Referrer URL | Never raw `Referer`; a safe page/task name if helpful | Route template or vetted path without query/fragment; full URL only if nonsecret and approved |
| Contact / next step | Application-owned support channel plus retry/correction guidance fitting the condition | Owning team/runbook, dependency, stage; do not make an outage look like user input error |
| Stack trace | Never | Actual exceptions with stacks and inner causes; for non-exception outcomes record code/reason, no invented stack |

### Approval for extra detail

For a requested full URI, raw exception message, or identifying value: classify it, then record diagnostic need, affected sinks (application, console, shipper, IIS/proxy), access controls, retention, approver, and review date. Approval covers **nonsecret** detail only; it never permits logging secrets, tokens, cookies, auth session IDs, or credential-bearing raw queries. Verify the logged path matches the **actual outbound request**, including appended query parameters; logging only the caller's unresolved route does not meet the diagnostic need. Log query keys or redacted values by default. An existing application that logs secret-bearing URIs is a **deviation from Crow policy**, not a Crow pattern: escalate a separate risk decision, contain all sinks, review retention, rotate exposed credentials, and plan to move credentials out of URLs. Application log filters do not control proxy/access logs.

## Failure contracts

| Case | User outcome | Operator outcome |
| --- | --- | --- |
| Known validation or verified denial | Field guidance or actionable toast; correct 400/401/403; reference if support may be needed | Stable reason/code, route, stage, status, correlation; no invented stack |
| Transient provider, DNS/TLS/socket, database, or signing-key failure | "Temporarily unavailable, retry later" + reference; 503-class where applicable; never a user-fault 400 for systemic failure | Real dependency/cause and timing; no HTTP status if no response was received (never manufacture one); no blind retry of non-idempotent or single-use actions |
| Unexpected exception | Root error page or safe Problem Details with reference, UTC time, contact; no internal message | Full stack/inner chain once at the handling boundary, linked to the initiating operation and trace |
| Client cancellation / server deadline | Do not report deliberate navigation/cancel as outage; message only if the client can still receive it | Start plus canceled/timed-out outcome, which token/deadline fired, elapsed time; not every cancellation is a timeout |
| Null/invalid dependency result | Preserve documented meaning and status; never turn denial into fake 503 | Own stage and reason, with trace |
| Stuck process or background failure | Independent synthetic probe detects it; approved support route | In-flight start, latency/readiness alert, pre-recycle evidence, controlled dump access |

## Exception boundary

- One framework-supported exception boundary per HTTP host plus the relevant interactive UI boundary. Do not add catch-all middleware where an adequate one exists; do not catch-and-log at every layer.
- API Problem Details and browser components share one deliberate reference contract (e.g. a `supportId` extension member) without internal exceptions.
- Preserve expected navigation and cancellation semantics; not every framework navigation exception is a fault.
- Global handlers do not cover startup failure, process hangs, every post-response failure, or background jobs: give those explicit logging and probes, and check startup failure through an independent platform path when the app logger is not initialized.
- Preserve existing public statuses and response shapes unless a separately reviewed compatibility change is approved.

## Technology notes

- **.NET:** use `ILogger<T>` message templates and scopes, the configured sink, `Activity`/W3C propagation, and the existing exception boundary. Inspect direct `HttpClient` calls as well as shared wrappers; do not prescribe NLog or a new telemetry stack.
- **.NET API support reference:**
  - Generate `supportId` server-side in one small middleware (or the existing correlation middleware) early in the pipeline, store it in `HttpContext.Items`, push it into an `ILogger` scope (`BeginScope`) so every log line carries it, and return it in a response header (e.g. `X-Support-Id`). Use only built-in .NET (.NET 10+): a small middleware, `ILogger` scopes, `Activity`, `AddProblemDetails`, and `IExceptionHandler`; no NuGet package is required. Reuse a correlation package only if the application already has one.
  - A caller-supplied `X-Correlation-Id` is untrusted: length-limit and character-validate it, log it as a separate `correlationId` field, and never use it as `supportId` or for authorization. Do not reuse `HttpContext.TraceIdentifier` alone as the user-facing reference (it is a local `requestId`); log it beside `supportId` and `Activity.TraceId`.
  - Register `AddProblemDetails()` with `CustomizeProblemDetails` to add `supportId`, `traceId`, and UTC `timestamp` extension members to every Problem Details response (validation, status-code, and exception), so API consumers and browser components share one contract. Keep `type`/`title`/`instance` stable and non-sensitive; `instance` is a route template or vetted path, not a query-bearing URL.
  - Implement an `IExceptionHandler` that maps known exception types to status codes and vetted titles/details through `IProblemDetailsService.TryWriteAsync`, and returns `false` or a generic 500 for unknown exceptions. Log the exception once there. Never copy `exception.Message` or `GetType().Name` into `detail`/`type` for the response (common tutorial pattern; it conflicts with the disclosure table above). Do not map every exception to 400; faults and dependency failures are 5xx.
  - Pair with `UseStatusCodePages()` so non-exception error statuses also return Problem Details with the same extensions. Preserve existing public statuses and response shapes unless a reviewed compatibility change is approved.
  - Propagate `supportId` to outbound calls only where the receiving service documents it; rely on W3C `traceparent` (via `Activity`/`HttpClient` instrumentation) for the verified cross-service join.
- **.NET exception-to-message catalog:** keep one small, central map (a static dictionary or switch expression owned by the exception boundary) from known exception/failure types or stable failure codes to `{ status, code, userMessageKey }`.
  - Resolve `userMessageKey` through the application's localization (`IStringLocalizer`/resources) to vetted, plain-language text with a next step, e.g. "We couldn't save your changes. Check the highlighted fields and try again." or "This service is temporarily unavailable. Try again in a few minutes."
  - Unmapped exceptions fall through to one generic 500 message plus the support reference; never fall back to `exception.Message`.
  - Log the stable `code` and the real exception once with the same `supportId`, so a developer sees the true cause while the user sees only the catalog text. Add a test that every catalog key has text in each supported language and that unmapped exceptions yield the generic message.
- **.NET error page (MVC/Razor/Blazor):**
  - Use `UseExceptionHandler("/Error")` (or the Blazor `ErrorBoundary` and the root error UI) in production; keep the developer exception page behind a development guard.
  - The error view model carries only `SupportId`, UTC time, catalog message, next step, and the application-owned contact channel. Read `SupportId` from the same request-scoped value the logs use; never from query strings or the raw exception.
  - Render the reference in a copyable element with a "Copy" control and an accessible label; announce and focus the error content per the UX accessibility guidance. Show no stack, raw exception text, URL, referrer, or session value.
  - Return the correct status (not 200) and `Cache-Control: no-store`. For API routes behind the same host, return Problem Details instead of the HTML page (`UseStatusCodePagesWithReExecute` for non-API paths only), so both paths show the same `supportId`.
- **Java:** use the chosen structured logger with MDC/context propagation, and the actual Servlet/Spring boundary (`@ControllerAdvice`/`ProblemDetail`, error filter). Verify context propagates across async executors and outbound clients.

## Acceptance checks

1. Enumerate browser, API, worker, startup, identity-provider, and outbound-dependency boundaries and their actual sinks. For **each deployable host**, prove a synthetic failure reaches the restricted production-mode log: match the page/toast `supportId` for UI hosts, or job/trace ID for workers. Identify the deployed file/aggregation path, filters, permissions, retention, and delivery-failure alert. Never infer delivery from configuration alone.
2. Exercise: a known 400 with two distinct causes, verified 401/403, systemic 503, no-status DNS/TLS/socket failure, null response, cancellation, server deadline, slow pending call, unexpected exception. Assert user text/status, exact structured fields, stage/elapsed time, stack and inner cause when applicable, and matching start/terminal IDs. The pending call must emit a start with a pre-call ID without a terminal event.
3. From a browser-visible reference, locate the host error, follow a **verified** W3C trace to the receiving service, and identify the upstream stage. Missing propagation must be detectable, not an invented join. For a call that never returns, the client attempt reference must join the pre-call event, or the operator locates it by UTC time and task. Check localized/accessible announcement, focus, and copy/paste.
4. With **synthetic** credentials and personal-data sentinels (never real secrets), inspect the user page, API response, application/console targets, automatic HTTP-client events, and proxy/access logs. Assert secrets and raw referrers are absent from all sinks, raw exception text is absent from user content, and a vetted/redacted cause plus stack remain in the restricted log. For approved nonsecret raw detail, verify access and retention at every sink.
5. Exercise a synthetic readiness failure and a running-but-unresponsive host. Confirm the monitor alerts, the operator can collect pre-recycle evidence under a runbook, and a routine app-pool health check is not reported as availability proof. New logs cannot reconstruct earlier outages whose evidence was never captured.

Apply across all affected deployable hosts and shared clients. Keep examples and tests public-safe: no real domains, private paths, incident transcripts, account references, credentials, or captured logs.
