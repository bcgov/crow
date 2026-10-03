# Java integration tests

Read the existing test harness and deployment configuration first. Choose the smallest real boundary that establishes the claim: Spring MVC test slice for MVC mappings/filters, in-process full HTTP server for connector/session behavior, or deployed WAR/container for server-owned behavior.

- For real HTTP assertions cover routing, serialization, authentication, authorization (including wrong tenant/object), CSRF for cookie writes, CORS, size limits, error contract, and health exposure. MockMvc alone does not test actual connector/proxy/TLS settings; exercise those in a running server/deployment when they matter.
- For persistence, use the target database engine when checking migrations, constraints, SQL dialect, collation, transactions, and locking. Testcontainers is useful when permitted and supported; otherwise use a controlled disposable or isolated test environment. In-memory substitutes cannot prove production database semantics.
- Ensure isolation with per-test identifiers, controlled fixtures and cleanup; never reset a shared database or call production-like external services. Read persisted state in a new transaction/context. Test both rejection and absence of unauthorized writes.
- For external Tomcat, Jetty, Undertow, or Jakarta EE servers, test the packaged WAR with the actual target version/profile and configured edge/proxy boundary. Embedded JAR tests alone cannot prove external WAR classloading, container authentication, forwarded headers, cookies, or management exposure.
- Bound waits/timeouts and capture useful logs on failure. Assert CI discovers/runs integration tests (for Maven check Failsafe `verify` and matching `*IT`/`IT*` names or explicit includes; for Gradle check the registered integration-test task), publishes reports, and fails on test failures.

## Sources

- Spring Framework, [Testing](https://docs.spring.io/spring-framework/reference/testing.html)
- Spring Boot, [Testing](https://docs.spring.io/spring-boot/reference/testing/index.html)
- Testcontainers, [Java documentation](https://java.testcontainers.org/)
- Apache Maven, [Failsafe Plugin](https://maven.apache.org/surefire/maven-failsafe-plugin/)
