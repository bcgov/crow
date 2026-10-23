# PHP safe persistence implementation

Database selection, schema/domain modelling, and data platform architecture remain out of scope.

- Keep transactions at the use-case boundary; roll back on failure and do not hold a transaction across an outbound network call. Know which database statements implicitly commit; test migration behavior against the target engine.
- Use PDO prepared statements or the framework's parameterized query builder/ORM for values. For raw PDO MySQL connections, declare the connection charset in the DSN (for example, `charset=utf8mb4`) and disable emulated prepares where native prepares are supported; verify driver behavior rather than assuming the framework uses raw PDO. Placeholders cannot bind identifiers or SQL keywords: map requested sort fields, table/column names, and directions through explicit allowlists.
- Never treat an ORM entity or request array as an authorization boundary: scope reads/writes to the authorized user/tenant, allowlist writable fields, and test concurrent-update behavior.
- Run reviewed migrations under a controlled deploy owner. Verify encoding, collation, constraints, transaction behavior, and representative multilingual/Indigenous-language round trips on the real engine; fail visibly if schema and application code are incompatible.
- Keep credentials out of code and logs; grant the application and migration identities only their required database privileges. Load the shared `data-flow-sinks.md`, `auth-and-access-control.md`, and `secrets-and-credentials.md` security modules.

## Sources

- PHP, [PDO prepared statements](https://www.php.net/manual/en/pdo.prepared-statements.php)
- PHP, [PDO transactions](https://www.php.net/manual/en/pdo.transactions.php)
- OWASP, [SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
