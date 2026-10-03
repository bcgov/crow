# Java architecture module

Load for Java applications; add `java-web.md` only for web workloads. Respect an existing supported baseline rather than migrating a running application as a side effect of a structural change.

## Runtime and build boundaries

- For new services, choose an actively maintained LTS JDK supported by the selected framework, container, vendor, and deployment platform; JDK 25 is an LTS option, not a mandatory upgrade from 21 or 17. Pin the toolchain and test on the runtime actually deployed.
- Use the repository's Maven or Gradle wrapper and explicit plugin/dependency versions. Maven dependency management/BOMs are not a transitive lockfile; Gradle dependency locking and verification solve different problems. Review resolved dependencies, not just declared versions.
- Prefer the smallest viable deployable unit. Split Maven/Gradle modules only to enforce dependency direction or independent lifecycle; avoid a generic shared module.
- Keep business rules independent of HTTP, persistence, and hosting APIs where that boundary pays for itself. Put assembly in the executable's composition root (Spring configuration, Jakarta CDI bootstrap, or explicit wiring). Do not combine unrelated dependency injection runtimes without an ownership decision.
- Select executable JAR with an embedded server or WAR with an external container based on operational ownership, deployment controls, and existing hosting; do not assume a WAR has all the APIs available in a full Jakarta EE server.

## Runtime behavior

- Define per-dependency timeouts, bounded retries for safe/idempotent work, cancellation/interruption behavior, and backpressure. Virtual threads can simplify blocking I/O on supported JDKs and frameworks but do not increase database connections or remove downstream capacity limits.
- Keep transaction ownership at the use-case boundary. Assign schema migrations a controlled deployment owner; do not run competing schema upgrades from every replica.
- Make liveness, readiness, logging, metrics, tracing, and graceful shutdown part of the deployment contract. Keep secrets outside artifacts and images.
- Apply `unicode-and-utf8.md` to all text paths: Java `String` indexing counts UTF-16 code units, not user-perceived characters; choose explicit charsets, locale-aware comparison where needed, and test complete Unicode round trips.

## Sources

- OpenJDK, [JDK 25 release](https://openjdk.org/projects/jdk/25/)
- Oracle, [Virtual Threads](https://docs.oracle.com/en/java/javase/25/core/virtual-threads.html)
- Gradle, [Java toolchains](https://docs.gradle.org/current/userguide/toolchains.html)
- Apache Maven, [Reproducible Builds](https://maven.apache.org/guides/mini/guide-reproducible-builds.html)
