# Java testing, build, image, and CI guidance

- Match the existing Maven/Gradle build and test conventions; use JUnit Jupiter for new suites when no established framework exists. Test rules without a container using the Java [unit-test guidance](../../../crow-testing/modules/java/unit-tests.md), and framework, database, and HTTP boundaries using the Java [integration-test guidance](../../../crow-testing/modules/java/integration-tests.md).
- Run the repository's wrapper and existing formatter/static analysis first, then unit tests, integration tests, packaging, dependency/container vulnerability checks, and established quality gates. Maven `verify` and Gradle `check` must actually include the relevant test tasks; confirm reports exist and failures fail the pipeline.
- Pin the toolchain and plugin versions. Commit wrapper metadata and verify wrapper distribution/checksum provenance. Maven BOM/dependencyManagement aligns versions but does not freeze transitive resolution; use explicit reproducibility policy and controlled repositories. For Gradle use dependency locking **and** dependency verification when appropriate; locking versions is not artifact integrity checking.
- Audit resolved direct and transitive dependencies and runtime/container versions; keep suppression evidence, owner, and expiry. Publish a reviewable SBOM/provenance when the existing delivery process supports it.
- Build images with a supported patched JDK/JRE matching the chosen runtime and server. Run as non-root, keep images minimal but preserve required locale/timezone/fonts, limit writable paths and exposed ports, and keep secrets out of images. Test graceful shutdown and health probes in the deployed configuration.
- Promote the same verified artifact across environments; do not rebuild with mutable dependencies between verification and deployment.

## Sources

- Apache Maven, [Reproducible Builds](https://maven.apache.org/guides/mini/guide-reproducible-builds.html)
- Gradle, [Locking Versions](https://docs.gradle.org/current/userguide/dependency_locking.html)
- Gradle, [Verifying Dependencies](https://docs.gradle.org/current/userguide/dependency_verification.html)
- Spring Boot, [Testing](https://docs.spring.io/spring-boot/reference/testing/index.html)
