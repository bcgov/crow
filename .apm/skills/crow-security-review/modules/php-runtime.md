# PHP runtime and supply-chain review

Load only for PHP applications. Pair with the generic authorization, framework configuration, session/API, data-flow, secrets, and deserialization modules for the affected paths. Verify the deployed configuration, not merely checked-in defaults; report missing deployment evidence as unknown, not as an exploitable vulnerability.

- Inventory PHP release, extension versions, Composer dependencies and plugins, framework/CMS version, lockfile, and web server/FPM configuration. Compare runtime support and advisories against current official sources; run `composer audit --locked` for the lockfile when supported by the pinned Composer version. Check that `composer install` uses expected locked versions and that runtime platform requirements pass. Report absent or unavailable audits as coverage gaps.
- Trace web root/front-controller rules and direct-file requests: can clients fetch `vendor/`, `.env`, backups, logs, source, or uploads, or execute uploaded files? For Nginx/FPM verify only existing, intended scripts reach FPM; check `try_files`, `SCRIPT_FILENAME`, path-info fallback, and the FPM listener's exposure together before classifying a vulnerability.
- Verify production `display_errors` is off, errors are logged to a restricted sink, and diagnostic endpoints/debug modes are inaccessible to users. For native PHP sessions check `session.use_strict_mode` and ID rotation; for framework/CMS sessions verify their actual driver and fixation controls instead of applying native INI rules. Check secure/HttpOnly/appropriate SameSite cookies and CSRF on cookie-authenticated writes for the actual flow.
- Trace uploaded file validation, storage, permissions, and download routes; PHP upload checks alone do not make a file safe to serve or execute. Check dangerous deserialization (`unserialize`) on untrusted data, dynamic include paths, shell commands, and SSRF with the shared sink-tracing modules; do not label a sink vulnerable without a reachable untrusted path.
- Check that Composer plugins/scripts executed during install run only from trusted, reviewed dependencies on appropriately isolated CI/build hosts. Avoid treating `--no-plugins` or `--no-scripts` as a universal fix: builds may legitimately need them; verify provenance and execution policy.

## Sources

- PHP, [supported versions](https://www.php.net/supported-versions.php)
- PHP, [session security configuration](https://www.php.net/manual/en/session.security.ini.php)
- PHP, [file upload security](https://www.php.net/manual/en/security.filesystem.php)
- Composer, [plugins](https://getcomposer.org/doc/articles/plugins.md)
- Composer, [audit](https://getcomposer.org/doc/03-cli.md#audit)
