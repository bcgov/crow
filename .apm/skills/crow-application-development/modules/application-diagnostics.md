# Application diagnostics: error handling and logging

Goal: show the user a **friendly, generic message with a clear next step** and a support reference, while logging **enough restricted detail that anyone on the team can diagnose the failure** from that reference.

Scope: error handling, user-visible errors, and incident diagnosis for any user-facing application. Technology specifics live in [`dotnet/diagnostics.md`](dotnet/diagnostics.md) and [`java/diagnostics.md`](java/diagnostics.md); load only the matching one. Security-event auditing (authentication, authorization, privilege, credential changes) stays in [`security-logging-and-audit.md`](../../crow-security-review/modules/security-logging-and-audit.md). Error presentation, focus, and announcements follow the B.C. UX accessibility guidance when a UX skill is available. Examples are synthetic.

Industry anchors: RFC 9457 Problem Details, W3C Trace Context, OpenTelemetry semantic conventions, OWASP Logging and Error Handling cheat sheets.

## Tiers

- **Baseline (every application):** sections marked *(baseline)* and acceptance checks 1–4.
- **Full assurance (multi-service, external dependencies, or production-critical):** everything, including acceptance checks 5–7.

Start with the baseline; add full-assurance items when the application has the matching boundary. Do not block a baseline change on full-assurance work.

## Support reference *(baseline)*

- Every user-visible error shows one **support reference** that is also on every log line for that request or job.
- **Default:** use the server-generated W3C `traceId` (32 hex characters) as the reference, so one ID joins user, logs, and downstream traces.
- Use a separate opaque, random `supportId` instead when no trace exists (non-HTTP job, legacy host), or when the host accepts `traceparent` from untrusted public callers and the team wants a reference the client cannot choose. Log both.
- The reference is a lookup key, never authorization. Do not encode account, session, or topology in it.
- A caller-supplied correlation header is untrusted: length-limit and character-validate it and log it as a separate `correlationId` field.
- For background jobs and message consumers, the job/message ID plus `traceId` is the reference.
- If no response reaches the browser, do not claim a server reference exists; show a client-side attempt reference if the UI generates one, otherwise ask for the time and task.

## Where to show an error *(baseline)*

Choose the **least disruptive** surface that still lets the user act. Redirect to a full error page only when the user **cannot continue** on the current page.

| Situation | Surface | Notes |
| --- | --- | --- |
| Input the user can fix (validation, business rule) | Field-level messages plus an error summary | Keep the input. Usually no support reference needed. |
| An action failed but the page still works (save failed, transient dependency, conflict, partial failure) | Persistent in-page alert/notification ("toast") near the action or at page top | Keep the input; offer Retry when safe; show the support reference. Error notifications **must not auto-dismiss** and need a close control, so users can read and copy the reference (WCAG 2.2.1, 4.1.3). |
| One region/widget failed to load, rest of page is usable | Inline alert in that region | Component-level error boundary; rest of page stays interactive. |
| Not authenticated or session expired | **Redirect to sign-in**, then return to the task | Not an error page. Validate the return URL as local-only. Preserve unsaved input where practical or warn before it is lost. |
| Authenticated but not authorized (403) | Full access-denied page (render in place; no redirect loop) | Explain how to request access and who to contact. |
| Resource not found or no longer available (404/410) | Full not-found page | Offer a path back (search, home, list). |
| Unexpected failure while rendering the page, or the whole service is unavailable (500/503) | Full error page | Support reference, UTC time, next step, contact. Use `Retry-After` when known. |

For APIs and SPAs the client chooses the surface from Problem Details `status` and stable `code`: 401 → re-authentication flow; 403 → access-denied view; 4xx with field errors → inline; 5xx on an action → in-page alert; 5xx on initial route load → full-page error state.

## User message content *(baseline)*

- Say what happened in plain language, then what the user can do: retry, correct input, wait, or contact support. Do not blame the user for system faults.
- Content: message, next step, support reference (copyable, with a "Copy" control and accessible label), labeled UTC date/time, and the application-owned contact channel.
- Never show stack traces, raw exception messages, exception type names, SQL, internal hostnames, raw URLs or referrers, or session values.
- Keep messages in a central, localizable **error catalog** keyed by stable code (see below). Unknown failures get one generic message plus the reference.
- Error pages and error API responses return the real status (never 200) and `Cache-Control: no-store`.

## Error catalog and Problem Details *(baseline)*

- One central catalog maps known exception types or failure codes to `{ status, code, userMessageKey, retryable }`. Unmapped exceptions map to a generic 500 entry.
- APIs return RFC 9457 Problem Details: `type` is a stable URI per code that points to a docs or runbook page (or `about:blank`); `title` comes from the catalog; `detail` is vetted catalog text, never the exception message; extension members carry `code`, the support reference, and UTC `timestamp`. `instance` is a route template or vetted path, never a query-bearing URL.
- Send `Retry-After` on 429 and 503 when the server knows the wait; the UI can use it in the message.
- Do not map every exception to 400. Use 4xx for caller-correctable problems and 5xx for faults and dependency failures. Preserve existing public statuses and response shapes unless a reviewed compatibility change is approved.
- Test that every catalog key has text in each supported language and that an unmapped exception yields the generic message.

## What to log *(baseline)*

Use structured logging with stable field names. Every error event should answer **what was being attempted, for what, where, and why it failed**:

- **Correlation:** support reference, `traceId`/`spanId`, local request ID, job/message ID.
- **Runtime context:** service, environment, release version or commit, host/instance, UTC timestamp, elapsed ms.
- **Business context:** operation name, entity type and internal ID (for example permit or file number), tenant/organization, and a safe input summary (counts, enum values, which fields failed validation by **name**, not value). If a business identifier is itself personal (SIN, PHN), log an internal surrogate ID instead.
- **Failure detail:** catalog `code`, reason category, stage, dependency name, outbound method and route template (plus query **keys**), response status if one was received, stable upstream error code, exception type, message, full stack, and inner-exception chain.
- **Actor:** verified user/workload ID when authenticated; record initiator and target separately for impersonation. Never invent a user ID before sign-in.
- Attach correlation and business context once with a logging scope/MDC at the operation boundary so every line carries it. Keep high-cardinality values out of metric labels.

## Log levels *(baseline)*

| Level | Use for |
| --- | --- |
| Debug/Trace | Developer detail; off in production by default |
| Information | Normal operation outcomes; expected validation failures (or Debug if noisy); client cancellation |
| Warning | Handled but abnormal: transient failure that was retried, fallback or degraded mode used, slow call over threshold, unexpected-but-handled input |
| Error | The operation failed and the user saw an error: unhandled exception, 5xx, retries exhausted |
| Critical | The application cannot function: startup failure, lost required dependency for all users, data integrity failure |

Log each failure **once** at Error, at the boundary that handles it; inner layers add context instead of logging the same exception again. Never sample away Error or Critical events.

## Exceptions that carry diagnostic value *(baseline)*

- Throw with context: the message says what failed and includes the key identifiers ("Failed to load permit 12345 from registry"). Exception messages reach logs, so never put secrets in them.
- When wrapping, always pass the original as the inner exception/cause. Rethrow without resetting the stack.
- Do not catch, log, and rethrow (double logging), and do not catch and swallow. Catch only to add meaning, recover, or translate to a contract.
- Use specific exception types or result types for expected failures (validation, not found, conflict) so the catalog can map them; do not use generic exceptions for control flow.

## Secrets and sensitive values *(baseline)*

**Default: do not log secrets** (passwords, tokens, API keys, cookies, session IDs, private keys, connection-string passwords, credential-bearing URLs). Diagnosis should not be blocked by this rule. Use the steps below in order.

### Step 1: safe stand-ins (always allowed, usually enough)

| Need | Log instead |
| --- | --- |
| Was a credential sent or configured? | presence, length, scheme/type (e.g. `Bearer`), configuration **key name** and source (not value) |
| Is it the right or expected credential? | key ID (`kid`), certificate thumbprint/subject/expiry, last 4 characters, or a keyed fingerprint (truncated HMAC-SHA-256 with a log-fingerprint key; never an unkeyed hash of a low-entropy secret) |
| Why was a token rejected? | non-secret claims: `iss`, `aud`, `exp`, `nbf`, `iat`, scopes/roles, client ID; validation failure reason. Never the signature or whole token |
| Which database/endpoint? | connection string with password removed; host, database, user name |
| Which URL failed? | scheme, host, path or route template, query **keys** with values redacted |

### Step 2: diagnostic escape hatch (when stand-ins do not resolve the issue)

Allowed in any environment, including production. Keep it lightweight; it must not slow down diagnosis:

- A configuration switch that is **off by default** and carries an **expiry time**; code ignores it after expiry. Changing it needs no code deployment.
- Scope it as narrowly as practical: one dependency, endpoint, log category, or user/support reference.
- Write sensitive values to a **dedicated log category or sink** with restricted access and short retention.
- Record one line when enabling: who, why (incident or support reference), scope, and expiry. Notify the owning team. No approval board is required.
- Afterwards: switch off, purge the restricted entries when no longer needed, and **rotate any credential that was logged**, since it is now exposed.
- End-user passwords and one-time/MFA codes are excluded: they are never needed for diagnosis and cannot be rotated by the team. Use stand-ins.
- Application log filters do not control proxy, IIS, or platform access logs; check those sinks separately.

An existing application that logs secrets **without** this switch is a deviation to fix, not a pattern to copy.

## Exception boundary *(baseline)*

- One framework-supported exception boundary per HTTP host plus the UI's error boundary; do not add catch-all middleware where an adequate one exists.
- API Problem Details and browser error pages share one reference and catalog contract.
- Preserve expected navigation and cancellation semantics; not every framework navigation exception is a fault. Do not report a user-cancelled request as an outage.
- Global handlers do not catch startup failure, process hangs, post-response failures, or background jobs. Give those explicit logging, and detect startup failure through a platform path when the app logger is not initialized.

## Browser and SPA errors

- Errors that never reach the server are invisible without client reporting. Use the framework error boundary plus global `error` and `unhandledrejection` handlers.
- Send a minimal structured report to an authenticated (or strictly rate-limited) server endpoint: client attempt reference, route template, release, browser, error name and stack. No form values, tokens, or storage contents. The server logs it with its own reference and treats all fields as untrusted.
- A failed fetch shows the in-page alert pattern above with whatever reference is available.

## Outbound calls *(full assurance)*

- Prefer the platform's built-in HTTP client instrumentation (traces, metrics, logs) for start, duration, and status. Add hand-written start and terminal events only where business stage context is needed or the built-in signal is not exported.
- Record elapsed time even when no response exists. Never manufacture an HTTP status for a connection failure.
- Classify DNS, TLS, socket, deadline, client cancellation, provider denial, invalid response, and downstream 4xx/5xx only when evidence supports it. Preserve transport exception types and inner causes.
- Where a call can hang, emit a start event before the await so a missing terminal event is an investigation lead. Logging alone cannot diagnose a hung process; pair with an independent latency/readiness signal.
- Verify W3C trace propagation in a deployed test; a local request ID is not proof of cross-service propagation. Label missing propagation as missing.

## Failure contracts

| Case | User outcome | Operator outcome |
| --- | --- | --- |
| Validation or verified denial | Field guidance or access-denied page; correct 400/401/403 | Stable code, route, stage, status, correlation; no invented stack |
| Transient dependency, DNS/TLS/socket, database, signing-key failure | "Temporarily unavailable, try again later" in-page alert or 503 page with reference and `Retry-After` when known; never a user-fault 400 | Real dependency, cause, and timing; no status if none received; no blind retry of non-idempotent actions |
| Unexpected exception | In-page alert for an action, full error page for a page render; reference, UTC time, contact | Full stack and inner chain once at the boundary, with business context and trace |
| Client cancellation / server deadline | No outage message for deliberate navigation or cancel | Cancelled vs timed-out, which deadline fired, elapsed time |
| Null/invalid dependency result | Preserve documented meaning; never turn a denial into a fake 503 | Own stage and reason, with trace |
| Stuck process or background failure | Independent synthetic probe detects it | In-flight start, latency/readiness alert, pre-recycle evidence |

## Acceptance checks

Baseline:

1. Trigger a synthetic failure on each deployable host and find it in the **actual deployed log sink** (not just local console) using the support reference shown in the UI or API response. Confirm business context, stack, and inner chain are present.
2. Exercise a fixable validation error, a 403, a 401/expired session, a 404, a transient dependency failure, and an unexpected exception. Assert the surface (inline, in-page alert, redirect to sign-in, or full page), status, catalog text, reference, `no-store`, and that input is preserved where expected.
3. With **synthetic** credential and personal-data sentinels (never real secrets), assert they are absent from user responses and all log sinks while the escape hatch is off; present only in the restricted sink while it is on; and absent again after expiry.
4. Check accessible announcement, focus, persistence (no auto-dismiss), and copy of the reference on the real UI.

Full assurance:

5. From a browser-visible reference, follow a verified W3C trace to the receiving service and identify the upstream stage. Missing propagation must be detectable, not invented.
6. Exercise no-status DNS/TLS/socket failure, server deadline, and a pending call that never returns; assert classification, elapsed time, and a start event without a terminal event.
7. Exercise a readiness failure and a running-but-unresponsive host; confirm alerts fire, operators can collect pre-recycle evidence under a runbook, and process liveness alone is not reported as availability. Inspect proxy/access logs for sentinel leakage.

Keep examples and tests public-safe: no real domains, private paths, incident transcripts, account references, credentials, or captured logs.
