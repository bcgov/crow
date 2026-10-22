# PHP development foundation

- Identify the runtime, framework, required extensions, `composer.json`/`composer.lock`, and project conventions. Respect the declared PHP minimum and deployed version; use current syntax and strict typing (`declare(strict_types=1)`) for new files when consistent with the application, not as a blind rewrite of legacy code.
- Use Composer autoloading and the existing framework's dependency container where present. Keep mutable state request-scoped; PHP-FPM requests and independently run workers need explicit state and resource lifecycles.
- Validate untrusted input at its boundary, authorize the resource/action at the point of use, and choose output encoding for the destination. Prefer `htmlspecialchars($value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8')` for plain HTML text/attributes; use the template engine's escaping rules in templates and distinct encoders for JavaScript/URLs.
- Use `password_hash`/`password_verify` for passwords and `random_bytes` for security tokens. Do not use `unserialize` on untrusted data, including cookies or cached payloads whose integrity cannot be verified; prefer structured formats with explicit validation.
- Use exceptions or explicit failure results; do not use `@` to suppress errors or catch `Throwable` and continue as if successful. Keep secrets outside source and deployment artifacts. For user-visible errors and logs load the shared application diagnostics module and `php/diagnostics.md`.
- Apply the Unicode/UTF-8 module on every text path; `strlen` measures bytes, `mb_*` measures code points in a specified encoding, and neither counts user-perceived graphemes.

## Sources

- PHP, [supported versions](https://www.php.net/supported-versions.php)
- PHP, [password hashing](https://www.php.net/manual/en/function.password-hash.php)
- PHP, [HTML escaping](https://www.php.net/manual/en/function.htmlspecialchars.php)
- PHP, [unserialize warning](https://www.php.net/manual/en/function.unserialize.php)
