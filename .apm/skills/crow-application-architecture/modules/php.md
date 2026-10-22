# PHP application architecture

Load for PHP applications; add `php-web.md` only for HTTP workloads. Identify the actual framework, PHP version, extensions, Composer project roots, and hosting model before choosing a structure. Preserve a supported existing baseline rather than migrating it as a side effect of another change.

## Boundaries and lifecycle

- For a new application select a currently supported PHP release compatible with the framework, extensions, and host. Check [PHP's supported versions](https://www.php.net/supported-versions.php) at decision time; pin the runtime and extension requirements across `composer.json`, images, and CI.
- Keep business rules separate from HTTP and persistence where that boundary pays for itself; put wiring at the application entry point or framework container. Split Composer packages only for independently owned or enforceable boundaries, not to add layers.
- Choose server-rendered pages, API, CLI, and queue workers from actual workload needs; request-scoped PHP-FPM workers do not provide a durable background job runner. Plan idempotency, retry limits, and shutdown for separate workers.
- Give schema migrations one controlled deployment owner. Define storage, cache, session, and queue ownership and what happens when each dependency is unavailable; never rely on process-local state across requests or replicas.
- Apply the shared Unicode/UTF-8 module across HTTP, PHP strings, database collation, exports, and templates; byte length (`strlen`) is not a character or grapheme count.

## Sources

- PHP, [supported versions](https://www.php.net/supported-versions.php)
- Composer, [schema: platform packages and PHP requirements](https://getcomposer.org/doc/04-schema.md#platform)
- PHP, [FastCGI Process Manager](https://www.php.net/manual/en/install.fpm.php)
