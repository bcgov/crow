# PHP web architecture

Load with `php.md` for PHP HTTP workloads. Determine whether the application uses Laravel, Symfony, WordPress, another framework, or plain PHP; do not impose one framework's middleware, directory layout, or deployment commands on another.

- Expose only the intended public document root/front controller. Keep `vendor/`, source, configuration, backups, logs, and uploaded files outside the web root or explicitly inaccessible; verify the web server's actual routing and direct-file behavior.
- When using Nginx with PHP-FPM, pass only existing, intended PHP scripts to FPM (for example with `try_files` in the PHP location) and verify `SCRIPT_FILENAME`/path-info handling; keep uploads outside that PHP location. Restrict the FPM listener to authorized web-server clients.
- Place authentication in the framework's request boundary and enforce per-resource/action authorization in the owning use case. Decide session, token, CORS, CSRF, and cookie rules from the credential topology; use [`api-contracts.md`](../../crow-application-development/modules/api-contracts.md) for REST/SOAP changes.
- Bound body and upload sizes at both web server and PHP/application layers. Specify trusted proxy headers, HTTPS termination, rate limits, and a safe error response at the actual edge; never trust client-supplied forwarding headers by default.
- Design user-upload storage without executable access or user-controlled public paths. Define object ownership, content/size checks, download headers, cleanup, and expiry before enabling uploads.
- Define liveness/readiness, structured diagnostics, deploy rollback, and separate worker health when jobs are asynchronous. Treat FPM process limits and database connection capacity as independently bounded resources.
- For FPM deployments, check whether required runtime configuration reaches worker processes: `clear_env` clears their environment by default. Prefer explicit pool `env[NAME]` entries or the approved secret provider over exposing every environment variable with `clear_env = no`.

## Sources

- PHP, [security: filesystem](https://www.php.net/manual/en/security.filesystem.php)
- PHP, [FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
- OWASP, [File Upload Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html)
