# Semgrep Rules: Index and Limits

Rules live in [rules/semgrep/](./rules/semgrep/). There are **9 YAML files containing 15 standalone rule IDs**. Each `*.yaml` has companion test fixtures with `ruleid:`/`ok:` annotations.

All rules are **triage heuristics**. A hit becomes a finding only after Step 0 + Seven Steps of the forensic doctrine confirm an actual reachable path.

## Tested Rules Catalog (15 Rule IDs across 9 Files)

| Rule ID | Language | Classification | Confidence | Target Mechanism |
| :--- | :--- | :--- | :--- | :--- |
| `ambient-header-identity-trust` | TS/JS | PERIMETER-BYPASS | Medium | Direct extraction of identity from ambient proxy headers (`x-forwarded-user`, `sm_user`, `x-user-id`, `x-ms-client-principal`, `remote_user`) without verified signature |
| `php-ambient-header-identity-trust` | PHP | PERIMETER-BYPASS | Medium | Direct extraction of identity from `$_SERVER['HTTP_SM_USER']`, `$_SERVER['HTTP_X_MS_CLIENT_PRINCIPAL']`, or PSR-7 headers without signature |
| `java-ambient-header-identity-trust` | Java | PERIMETER-BYPASS | Medium | Direct extraction of identity from `request.getHeader("SM_USER")`, `request.getRemoteUser()`, or `x-ms-client-principal` without signature |
| `csharp-check-then-act-balance` | C# | TOCTOU-RACE | Medium | `GetBalance()` check followed by `DeductBalance()` across independent connections or without serializable isolation |
| `fail-open-authorization-handler` | TS/JS | FAIL-OPEN-AUTH | Medium | Catch-block in authorization check returning `true`, `allow`, `{ allowed: true }`, or Express `next()` error bypass |
| `java-transactional-self-invocation` | Java | TRANSACTION-DEMARCATION | Medium | Calling `@Transactional` method on `this` bypassing Spring AOP proxy |
| `java-requires-new-partial-commit` | Java | TRANSACTION-DEMARCATION | Low | EJB / Spring `@Transactional(REQUIRES_NEW)` causing non-atomic partial commits |
| `php-sql-by-id-without-tenant-predicate` | PHP | TENANT-LEAK | Low | SQL query by ID (`id =`, `invoice_id =`) or ORM find/findBy lacking organizational scope parameter |
| `plsql-autonomous-transaction-business-dml` | PL/SQL | TRANSACTION-DEMARCATION | Medium | Autonomous unit executing UPDATE/DELETE/MERGE or non-audit INSERT and COMMIT |
| `plsql-autonomous-transaction-in-trigger` | PL/SQL | TRANSACTION-DEMARCATION | High | Autonomous trigger workaround for ORA-04091 mutating table |
| `plsql-auth-function-when-others-allow` | PL/SQL | FAIL-OPEN-AUTH | Medium | Authorization function with `WHEN OTHERS THEN RETURN TRUE` or `'Y'` masking database errors as permission grants |
| `plsql-vpd-policy-empty-predicate` | PL/SQL | FAIL-OPEN-AUTH | Medium | Oracle Virtual Private Database (VPD) policy function returning `NULL` or empty string, disabling row-level security |
| `plsql-null-expands-scope-filter` | PL/SQL | TENANT-LEAK | Medium | SQL where-clause using `(:param IS NULL OR col = :param)`, NVL, or DECODE, expanding tenant scope to all rows on null bind |
| `python-django-read-modify-write` | Python | LOST-UPDATE | Medium | Django ORM `get()` → field mutate → `save()` lost update race (mitigated by `F()` expressions or `select_for_update`) |
| `ts-floating-mutation-promise` | TS/JS | ERROR-SWALLOW | Low | Un-awaited `save/update/delete/charge` mutation in async Express route handler |

## Execution Protocol

Run tests across all rules:
```bash
semgrep --test references/rules/semgrep
```
