# Java unit tests

Detect first: inspect Maven/Gradle test dependencies/plugins, the existing tests, assertions, fixtures, and test runner configuration. Follow a meaningful existing suite; for a new Java suite prefer JUnit Jupiter with versions managed by the project's framework BOM or build platform. Do not mix JUnit 4/Vintage into new tests merely because migration support exists.

- Exercise domain/application rules without booting Spring or a Jakarta server. Use fakes at owned interfaces only when they make an observable behavior test more precise; do not mock every value or internal call.
- Cover valid, invalid, boundary, ownership, cancellation/interruption, and dependency-failure outcomes relevant to the code. Use parameterized tests for rule tables and deterministic clocks/random data for time- or randomness-sensitive behavior.
- Distinguish assertions on outputs and state from brittle interaction tests. Test Unicode/UTF-8 round trips and grapheme/collation rules when relevant; avoid ASCII-only fixtures for user text.
- For Spring code, reserve context tests and test slices for real framework wiring; a test booting the application is an integration test. Configure Gradle test tasks with `useJUnitPlatform()` for Jupiter and a compatible Maven Surefire/JUnit engine; assert nonzero discovered tests rather than treating a green zero-test run as success.
- On framework migration, run the old and new suites against the same contract before deleting compatibility engines; require a deliberate decision rather than silently rewriting an established test suite.

## Sources

- JUnit, [User Guide](https://docs.junit.org/current/user-guide/)
- Spring Boot, [Testing](https://docs.spring.io/spring-boot/reference/testing/index.html)
