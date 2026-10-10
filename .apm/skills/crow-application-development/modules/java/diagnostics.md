# Java application diagnostics

Load with [`../application-diagnostics.md`](../application-diagnostics.md). Intentionally thin; expand when Java guidance is prioritized.

- Prefer the framework's built-in Problem Details support (Spring `ProblemDetail`) and error boundary (`@RestControllerAdvice`, Servlet error page). Keep `server.error.include-stacktrace` and `include-message` at `never` in production.
- Put the support reference and business context in MDC at the operation boundary; clear it in `finally`, and copy it across async executors.
- Log exceptions with the exception as the last logger argument so the stack and cause chain are written. Wrap with `new XException("message", cause)`.
