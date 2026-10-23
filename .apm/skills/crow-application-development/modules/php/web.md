# PHP web development

- Inspect framework version, route/middleware order, actual session/authentication driver, proxy configuration, and web server before editing. Use the parent `api-contracts.md` for REST/SOAP work.
- Enforce authentication and object/tenant authorization server-side; default private routes to deny. Protect cookie-authenticated state changes with the framework's CSRF mechanism, including non-form writes; do not disable CSRF globally to fix a request.
- Set session cookies Secure on HTTPS, HttpOnly, and an appropriate SameSite policy. For native PHP sessions enable strict ID handling; for framework-managed sessions inspect the framework's session driver and fixation protections instead of assuming PHP INI settings apply. Rotate the ID at authentication/privilege changes using the session handler's safe strategy; for native sessions account for concurrent requests and old-ID invalidation rather than deleting old data blindly. Do not leak session IDs via URLs or expose secrets in client code.
- Keep framework template auto-escaping enabled and encode raw output for its actual context. Validate redirects against approved destinations, restrict CORS to intended origins, and verify proxy headers come only from trusted proxies.
- Bound `post_max_size`, `upload_max_filesize`, application validation, and edge limits; check upload error codes, allowlist file types and inspect content server-side (for example with `finfo_file`), never trust the client-supplied MIME type. Use `move_uploaded_file` or framework-safe storage, generate server-side names, and keep uploads non-executable and outside the public root when possible. For Nginx/FPM, verify only intended existing PHP scripts are forwarded to FPM; do not let path-info fallback execute an uploaded file.
- Return real HTTP error statuses and safe details; expose no stack traces or PHP warnings in production responses. Use the shared diagnostics and PHP companion modules for support references and logging.

## Sources

- PHP, [session security](https://www.php.net/manual/en/session.security.ini.php)
- PHP, [file uploads](https://www.php.net/manual/en/features.file-upload.php)
- PHP, [session ID regeneration](https://www.php.net/manual/en/function.session-regenerate-id.php)
- OWASP, [Cross-Site Request Forgery Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)
