# PHP application diagnostics

Load the generic [`application-diagnostics.md`](../application-diagnostics.md) in full. This companion is intentionally narrow; it does not replace the generic baseline.

- Register one framework exception/error boundary for HTTP and an explicit failure boundary for CLI/queue workers. Disable `display_errors` in production, enable restricted error logging, and never expose exception messages, stack traces, paths, or PHP warnings in responses. Preserve real HTTP statuses and `Cache-Control: no-store` on error responses.
- Use the framework's error renderer and logger where present. Otherwise, implement the shared safe error catalog and support reference at the boundary, using a trusted trace or generated identifier and verifying lookup in the deployed log sink. Do not label an arbitrary request ID as a W3C trace ID.
- Log exceptions with their cause chain and safe structured operation context once at the handling boundary. Do not log cookies, authorization headers, tokens, uploaded contents, or raw URLs. Propagate approved correlation context explicitly to asynchronous jobs and clear it between long-running worker jobs.

## Sources

- PHP, [error reporting configuration](https://www.php.net/manual/en/errorfunc.configuration.php)
- PHP-FIG, [PSR-3 Logger Interface](https://www.php-fig.org/psr/psr-3/)
