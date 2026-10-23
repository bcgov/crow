---
name: crow-ci-pipelines
description: Assess, troubleshoot, and author Java, .NET, or PHP CI in GitHub Actions, Azure Pipelines, or Jenkins, including existing tests, database-change artifacts, and Sonar version discovery when scanning.
---

# CI Pipelines

Use for application CI, not for authoring operational releases, database
refreshes, or production deployments. Assess those separately and preserve
their existing approval and data-handling boundaries.

## Route by evidence

1. Read [`modules/foundation.md`](modules/foundation.md) on every CI task.
   Inspect the repository root, workflow locations, build manifests, runtime
   pins, test projects, tool availability, and existing branch protection.
   A repository may intentionally run multiple CI providers: do not choose
   one merely because a marker file exists.
2. Load [`modules/github-actions.md`](modules/github-actions.md) for
   `.github/workflows/` or an explicitly requested GitHub workflow.
   Load [`modules/azure-pipelines.md`](modules/azure-pipelines.md) for
   Azure YAML, classic assessment, or a classic-to-YAML migration.
   Load [`modules/jenkins.md`](modules/jenkins.md) for a `Jenkinsfile`
   or an explicitly requested Jenkins pipeline. Load multiple provider
   modules only when multiple providers are in scope.
3. For a .NET solution/project, load the existing
   [`.NET CI module`](../crow-application-development/modules/dotnet/testing-ci.md).
   For a Java Maven/Gradle project, load the existing
   [Java CI module](../crow-application-development/modules/java/testing-ci.md);
   confirm it builds Java rather than assuming all JVM builds do. In a
   PHP project, load the
   [PHP CI module](../crow-application-development/modules/php/testing-ci.md).
   In a polyglot repository, load only the languages in scope.
4. Add future languages by routing their application-development CI module,
   without weakening the common gate or duplicating provider guidance.
   Unknown technologies require discovery, not invented commands.
5. Only when Sonar scanning is part of the requested pipeline, load
   [`../crow-sonar-scan/modules/project-version.md`](../crow-sonar-scan/modules/project-version.md)
   to resolve `sonar.projectVersion` for the **target application**. This
   module supplies version discovery, not authorization to invoke the
   Sonar MCP scanner while authoring a pipeline. If no supported version
   source is found, omit the optional property and report why; do not
   invent a version or silently use Crow's package version.

## Modes

- **Assess:** inventory triggers, stages, builds, tests, scanners, artifacts,
  permissions and observed failures; distinguish measured behavior from
  guessed intent. For classic Azure definitions, request detail when listing
  tools expose only names and identifiers.
- **Troubleshoot:** reproduce the failing command when safe, identify the
  earliest failed stage and its root cause, and repair the pipeline without
  bypassing a failing check.
- **Author:** confirm runner/toolchain, triggers, branch policy, target
  artifact, required gates, all existing unit/integration/UI suites, and
  any database-change assets before adding the smallest valid provider
  configuration. Default to wiring every runnable existing suite and
  packaging applicable database changes; investigate missing infrastructure
  rather than silently skipping a suite. Request approval for consequential
  security or publication changes.
- **Migrate:** inventory the classic build and release process, map each
  observable requirement to a reviewed Azure YAML equivalent, run both
  paths when practical, and cut over only after parity and rollback are
  agreed. Do not silently replace deployment or operations jobs with CI.

## Completion gate

The selected provider and language modules reflect evidence; generated
configuration passes available lint and build checks; all discovered
automated suites and applicable database assets are accounted for; required
reports and quality gates fail closed; any provider-side run, permission
change, or classic migration not verified is stated as outstanding.
