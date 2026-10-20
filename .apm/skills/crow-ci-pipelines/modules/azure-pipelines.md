# Azure Pipelines CI

Use when the [CI router](../SKILL.md) selects Azure. Apply the
[shared gate](foundation.md) and the routed Java or .NET CI module.

1. Confirm Azure DevOps Services vs. Server version, source provider,
   available agent pool/OS/tools, approved service connections, and
   organization policies. Inspect classic builds through the Build service
   and classic releases through the Release service; the Pipelines listing
   does not provide the classic task graph. If definition detail is missing,
   request a sanitized export or authorized read-only API access instead
   of inferring steps from names.
2. For new work write only repository-owned Azure pipeline YAML. Match task
   versions and features to the **actual** server and installed extensions;
   do not assume Services-only hosted agents, caching, environments, or
   pull-request features exist on an older Server. Use reviewed templates
   when existing policy requires them. Restrict job authorization scope,
   repository permissions, and service connections to the required project
   and tasks.
3. Configure triggers appropriate to the source provider; GitHub PR and
   Azure Repos branch policies have different validation controls. For
   GitHub-sourced builds, confirm the GitHub connection's read scope and
   validate the source revision against the shared fork/agent trust rules.
   Review provider-level fork build settings: disable automatic fork runs
   on internal agents or use an isolated agent with no internal access.
4. For Java choose the existing wrapper and verified JDK; for .NET choose
   the verified SDK and solution/project. Restore, lint, build, run every
   discovered unit, integration, and UI test suite, publish actual reports,
   and enforce audit/coverage/quality gates before artifact publication.
   Package database changes under the common artifact rule, not as an
   implicit deployment. Add SonarQube Prepare/Analyze/Publish only when the installed
   extension supports the selected version. The Publish task's
   `pollingTimeoutSec` only bounds polling and reports the gate; it does
   not make a red gate fail the build. When the gate must block CI, set
   `sonar.qualitygate.wait=true` and a bounded timeout in the Prepare task's
   `extraProperties`, or use a verified blocking check. Verify that a red
   or missing result fails the job. Do not embed host URLs or credentials
   in YAML.
5. For classic migration, document the original steps, task inputs,
   schedules, variables, artifacts, environments, approvals, and consumers.
   Map release approvals to supported environment checks with owners'
   agreement; never pretend a classic release exports to equivalent YAML
   automatically. Keep the original available for rollback until parity is
   verified. Leave operations/database maintenance outside CI scope.
6. Validate YAML locally, preview/validate it against the target Azure
   version when authorized, then run the relevant build and tests. State
   which trigger, service-connection, gate, and migration behaviors remain
   unverified without a provider-side run.

See [Azure Pipelines security](https://learn.microsoft.com/azure/devops/pipelines/security/overview),
[YAML templates](https://learn.microsoft.com/azure/devops/pipelines/process/templates),
and [classic-to-YAML migration](https://learn.microsoft.com/azure/devops/pipelines/release/from-classic-pipelines).
