# Java development foundation

## Language and dependencies

- Follow the application's declared source/target compatibility and supported runtime; for new services consider a supported LTS JDK compatible with the framework and container. Never enable preview features by default.
- Use records for immutable value/transfer types where serialization/binding supports them, sealed types where the domain is truly closed, and explicit nullability/validation at boundaries. Do not force persistence entities into immutable shapes incompatible with the selected provider.
- Prefer constructor injection and explicit ownership/lifetimes. Never put request-scoped or mutable state in an application-wide singleton without thread-safety and a clear lifecycle.
- Use `java.time` with an explicit `Clock` for testable time and `SecureRandom` for security-sensitive randomness. Avoid default time zones for external contracts.

## Failure, concurrency, observability

- Specify connect, read/request, and overall timeouts for outbound calls; propagate interruption and cancellation. Retry only transient operations with bounded attempts and idempotency safeguards.
- Use virtual threads only where supported and measured for blocking I/O; limit access to constrained downstream systems separately and test context propagation. Do not adopt preview structured concurrency APIs without an explicit compatibility decision.
- Handle errors once at a delivery boundary with safe, stable contract responses; do not catch broadly and then log-and-continue. Log structured diagnostic context without credentials, tokens, personal data, or high-cardinality metric labels.
- Validate configuration at startup and use an approved secret source instead of literals in source, `application*.yml`, build files, CI variables committed to the repository, or container layers.

## Text

Apply [`unicode-and-utf8.md`](../../../crow-application-architecture/modules/unicode-and-utf8.md) through the parent router. Use `StandardCharsets.UTF_8` where text encoding is required; `String.length()` and `charAt()` operate on UTF-16 code units. For user-visible character boundaries use a suitable grapheme-aware API/library; choose locale/normalization explicitly rather than stripping diacritics.

## Sources

- Oracle, [Java Platform, Standard Edition 25 documentation](https://docs.oracle.com/en/java/javase/25/)
- Oracle, [Virtual Threads](https://docs.oracle.com/en/java/javase/25/core/virtual-threads.html)
- OpenJDK, [JDK 25 release](https://openjdk.org/projects/jdk/25/)
