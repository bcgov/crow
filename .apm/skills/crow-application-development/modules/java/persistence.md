# Java safe persistence implementation

Database selection, schema/domain modelling, and data platform architecture remain out of scope.

- Own each transaction at the use-case boundary; understand Spring `@Transactional` proxy/self-invocation behavior or Jakarta transaction semantics before assuming a method is transactional. Avoid holding transactions open across remote calls.
- Keep JPA `EntityManager`/Hibernate sessions scoped to a transaction/request, not shared across threads. Avoid implicit lazy loading in serialization; project bounded response DTOs and check query count/N+1 behavior.
- Prefer prepared statements/bound parameters for JDBC, JPA, and native SQL. Allowlist dynamic identifiers and ordering fields; never concatenate untrusted SQL fragments.
- Restrict queries to the caller's authorized resource/tenant and map only writable fields from request DTOs. Enforce optimistic locking where concurrent updates would otherwise overwrite data.
- Generate and review Flyway/Liquibase or equivalent migrations, exercise them against the real database engine, and run under a controlled deploy owner with observable failure and rollback. Do not silently continue serving an unknown schema.
- Verify driver, database column encoding/collation, and migrations with representative multilingual and Indigenous-language round trips, not just Java `String` tests.
- Use narrowly scoped credentials/workload identity and redact SQL parameters or connection URLs containing secrets.

## Required Crow security modules

Load `data-flow-sinks.md`, `auth-and-access-control.md`, and `secrets-and-credentials.md` for persistence changes.

## Sources

- Jakarta Persistence, [Specification](https://jakarta.ee/specifications/persistence/)
- Spring Framework, [Declarative Transaction Management](https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative.html)
- OWASP, [SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
