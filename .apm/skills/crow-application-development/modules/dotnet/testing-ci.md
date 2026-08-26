# .NET testing, build, container, and CI guidance

## Tests

- Pair production projects with focused unit tests and add integration tests at framework/external boundaries.
- Unit-test domain/application behavior without booting the web host.
- Use `WebApplicationFactory` for routing, filters, middleware, authentication/authorization, serialization, and Problem Details behavior.
- Test success, invalid input, unauthenticated, forbidden, wrong-owner/tenant, cancellation, timeout, and dependency failure paths.
- Replace external systems with controlled fakes or disposable test infrastructure. Do not call shared production-like services from unit tests.
- Treat coverage as a diagnostic and enforce a meaningful repository threshold; merely checking that a coverage file exists is not a gate.

## Deterministic CI sequence

Use the repository's established equivalents in this order:

1. restore in locked mode;
2. formatting/analyzer verification;
3. release build without restoring again;
4. tests and coverage without rebuilding;
5. dependency vulnerability audit;
6. SAST/Sonar quality gate;
7. publish/package from the already verified source;
8. generate SBOM/provenance and immutable artifact metadata.

Fail on a missing report or failed quality gate. Do not turn security failures into warnings without an approved, time-bound exception.

## Dependencies

- Keep `packages.lock.json` for deployable applications and restore with `--locked-mode`.
- Centralize versions with `Directory.Packages.props` when the solution has enough projects to benefit.
- Remove migration-only analyzers and superseded packages after framework upgrades.
- Review transitive vulnerabilities and package provenance; do not resolve findings by suppressing them without reachability evidence.

## Containers

- Use multi-stage builds with SDK and ASP.NET runtime images matching the target framework.
- Restore after copying only dependency manifests to preserve caching, then publish from the complete source.
- Use a non-root runtime user, a read-only filesystem where possible, explicit writable mounts, and no secrets in layers.
- Keep the runtime image minimal and patchable. Pin digests when the release process supports automated refresh.
- Expose only required ports and provide platform-compatible health probes.

## Pipeline security

- Grant read-only repository permission by default and elevate individual jobs only when publishing.
- Pin or govern third-party pipeline actions/tasks.
- Use short-lived workload identity or scoped pipeline tokens.
- Build once and promote the same artifact through environments.
- Embed commit/version metadata so a running artifact maps back to source.

## Required Crow security modules

Load `secrets-and-credentials.md` and `deserialization-and-integrity.md`; add `crypto-and-transport.md` for signing, certificates, or custom TLS.

## Sources

- Microsoft Learn, [Integration tests in ASP.NET Core](https://learn.microsoft.com/aspnet/core/test/integration-tests)
- Microsoft Learn, [Containerize a .NET app](https://learn.microsoft.com/dotnet/core/docker/build-container)
- NuGet, [Package references in project files](https://learn.microsoft.com/nuget/consume-packages/package-references-in-project-files)

