# PHP integration tests

Choose the smallest real boundary for the claim: framework HTTP test client for routing/middleware, actual web server plus FPM for proxy/INI/server behavior, and the target database engine for SQL and migrations. A framework client alone cannot prove edge TLS, proxy, or upload limits.

- Exercise authentication, per-object/tenant authorization, cookie-write CSRF, CORS, session rotation, upload rejection/storage, template encoding, error response shape, and health exposure when relevant. Test both denial and absence of unauthorized side effects.
- Test migrations, constraints, transactions, driver behavior, and collation against a disposable or isolated target-engine database. SQLite in-memory is not evidence for another production engine. Use fixtures with ownership and cleanup; never reset shared or production data.
- Use real HTTP against the configured deployment when verifying document-root exposure, PHP-FPM/web-server routing, forwarded-header trust, body limits, and non-executable upload storage. Keep tests off production and run mutating calls only against approved isolated targets.
- Bound waits and capture sanitized diagnostics on failure. In CI verify the integration suite and required reports actually ran and fail the job if they did not; do not silently skip tests for unavailable services.

## Sources

- PHPUnit, [version-specific documentation](https://phpunit.de/documentation.html)
- PHP, [FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
- OWASP, [Web Security Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)
