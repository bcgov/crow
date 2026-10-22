# CI foundation and quality boundaries

Build a pipeline from the repository's existing build and test contract. Check
the pinned runtime, wrapper/SDK, dependency policy, executable test commands,
coverage format and numeric threshold, vulnerability policy, artifact format,
and promotion path. Do not substitute a generic command for a verified
repository command. A missing expected report or failing gate is a failure,
not a success-shaped warning.

## Existing tests and database artifacts

- Inventory every existing unit, integration, and automated UI suite using
  test projects, build targets, test scripts, current CI, and test docs.
  Confirm which commands actually execute each suite; `mvn verify`,
  `gradle check`, `dotnet test`, or `composer test` alone may omit separately configured
  integration or UI tests. Include **all** existing runnable suites by
  default, even when separate jobs or test services are required. Provision
  only approved disposable dependencies and test accounts. Never aim tests
  at production or place credentials on an untrusted PR runner.
- Publish the actual test results and enforce failure on test failure,
  missing required reports, or a suite that ran zero tests unexpectedly.
  If a suite needs unavailable infrastructure, identify the prerequisite
  and ask how to supply a safe runner; do not silently skip it or label a
  pipeline complete with that suite unverified. Do not invent new tests or
  treat manual UI QA as an executable suite.
- Check for source-controlled database changes used by the application:
  EF Core migrations, Flyway/Liquibase changelogs, PHP framework migrations,
  DACPAC/sqlproj outputs, or versioned SQL scripts. When present, include their ordered migration
  files and any required manifests or generated deployment artifact in the
  verified build package using the repository's established tooling.
  Verify the artifact contains the intended files and excludes connection
  strings, secrets, dumps, snapshots, and real data. Do not execute
  migrations or data fixes against a shared database in CI; deployment,
  approval, and rollback remain separate decisions. Fail if expected
  change files or packaged outputs are missing.

## Trust and supply chain

- Use isolated, least-privilege runners and job-scoped credentials. Review
  forks, external pull requests, workflow changes, and caches as untrusted
  input. Do not run untrusted source on self-hosted agents with internal
  network access, SonarQube credentials, or deployment permissions.
- Prefer provider-managed short-lived identity over long-lived tokens when
  supported. Keep secrets out of YAML, Jenkinsfiles, command output, build
  artifacts, cache keys, and container layers. Never depend on log masking
  as a security boundary.
- Restore dependencies reproducibly using the repository's lockfiles and
  verified wrappers; audit resolved dependencies with explicit failure
  policy. Keep build/test gates ahead of publishing. Promote the same
  verified artifact rather than rebuilding for deployment.
- Scope caches to non-secret dependency data with keys derived from
  trusted manifests. Do not allow untrusted pull requests to poison caches
  consumed by privileged jobs.
- Pin/gate third-party tasks, actions, tools, and container images according
  to provider capabilities; verify versions against current official docs,
  not examples copied from another repository.

## Sonar decision

1. First determine whether the project has an approved quality scanner,
   license/features, project key, coverage requirements, and a trusted
   network path. Do not create a new Sonar account or silently drop an
   existing quality gate.
2. A public GitHub workflow must not target an internal SonarQube server.
   SonarQube Cloud's Free plan supports public projects, subject to current
   plan terms and authorized onboarding. Use its GitHub integration or
   token-backed CI only where the event can safely receive the credential.
   Never inject a token into an untrusted fork build.
3. For internal Azure/Jenkins jobs, use SonarQube Server only after confirming
   runner reachability, approved credentials, scanner/extension compatibility,
   and whether branch/PR analysis is actually supported. An Azure pipeline
   may check out a public GitHub repository and scan it internally only on
   approved trusted revisions with an isolated agent and read-scoped
   connection. Do not grant fork code internal network access for a scan.
4. For .NET, wrap the actual build with SonarScanner for .NET begin/build/end.
   For Java, use the supported Maven or Gradle scanner; for PHP use an approved
   SonarScanner CLI or provider integration and import a generated Clover XML
   coverage report through `sonar.php.coverage.reportPaths` when coverage is required, after confirming the
   build, tests, and coverage tasks actually ran. Successful scan upload is
   not a passing quality gate: when the gate must block CI, configure the
   scanner's `sonar.qualitygate.wait=true` and a bounded
   `sonar.qualitygate.timeout`, or a verified provider gate that fails the
   job on failure or timeout. Azure's Publish Quality Gate Result task
   reports the result to the build summary; its polling timeout alone does
   not enforce a blocking gate. Require the gate before artifact promotion
   and verify failure, missing-result, and timeout behavior.

Consult the [GitHub secure-use reference](https://docs.github.com/en/actions/reference/security/secure-use),
[Azure pipeline security guidance](https://learn.microsoft.com/azure/devops/pipelines/security/overview),
[Jenkins credentials guidance](https://www.jenkins.io/doc/pipeline/steps/credentials-binding/),
[SonarQube Cloud plans](https://docs.sonarsource.com/sonarqube-cloud/administering-sonarcloud/managing-subscription/subscription-plans),
and [SonarScanner for .NET](https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/scanners/dotnet/using/)
and [quality-gate enforcement](https://docs.sonarsource.com/sonarqube-server/10.8/analyzing-source-code/ci-integration/overview)
for version-specific details.
