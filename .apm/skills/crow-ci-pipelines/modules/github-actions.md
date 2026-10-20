# GitHub Actions CI

Use when the [CI router](../SKILL.md) selects GitHub. Follow the
[common quality boundaries](foundation.md) and the routed Java or .NET
CI module.

1. Inspect existing `.github/workflows/`, branch rules, solution or wrapper
   files, lockfiles, test/coverage reports, and currently approved actions.
   Select PR and push triggers to avoid unintended duplicate runs; use
   `pull_request` for untrusted contributions. Never check out untrusted PR
   head code under `pull_request_target` or a privileged `workflow_run`.
2. Create a repository-specific workflow with `permissions: contents: read`
   by default; grant extra permissions only to the job that needs them.
   Prefer an action dependency lockfile; otherwise pin used actions and
   reusable workflows to verified full commit SHAs. Determine actual SHAs
   from the action's canonical repository, never invent one.
3. Set up the verified JDK or .NET SDK, restore using the project's lock or
   wrapper policy, run formatting/lint if configured, build, then run every
   discovered unit, integration, and UI test suite and enforce the configured
   coverage and audit gates. Follow the common artifact rule for database
   changes. For Java use the repository's Maven/Gradle wrapper when present;
   for .NET use its actual solution/project and locked restore only when
   lockfiles are present. Cache dependencies only with safe scopes and
   manifest-based keys.
4. Separate untrusted validation from publishing, signing, deployments,
   or secret-backed scans. Follow the shared Sonar decision; when an
   approved GitHub integration is used, confirm its event and token
   permissions before enabling PR analysis. A successful scan upload is
   not a passed gate; use an approved pinned quality-gate action or the
   scanner's bounded wait setting when the gate must block the job.
5. Run `actionlint` when installed (or the repository's established
   equivalent), execute the build/test commands, then verify that a
   real failing test, missing coverage report, failed audit, or failed
   quality gate would fail the job. State when GitHub-side execution or
   branch protection cannot be checked locally.

Use [GitHub's secure-use guidance](https://docs.github.com/en/actions/reference/security/secure-use)
and [workflow syntax reference](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
for current syntax and security behavior.
