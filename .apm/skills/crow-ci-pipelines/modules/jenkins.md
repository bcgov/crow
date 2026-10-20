# Jenkins CI

Use when the [CI router](../SKILL.md) selects Jenkins. Read the
[shared boundaries](foundation.md) and the routed Java or .NET CI module.

1. Inspect the existing `Jenkinsfile`, supported Jenkins/plugins, source
   checkout, triggers, shared libraries, agent labels and tools. Ask for
   the actual agent image or installed JDK/.NET SDK and OS when they cannot
   be verified. Do not assume `agent any` has the required toolchain or
   copy internal node labels into distributable examples.
2. Write a repository-owned **Declarative Groovy** `Jenkinsfile` with
   `pipeline`, an appropriate agent, and stages for verified restore/build,
   every discovered unit, integration, and UI test suite, required gates,
   and applicable database-change packaging. Use `sh`, `bat`, or
   `powershell` according to the real agent OS. Fail on missing test results
   or coverage when these reports are required, rather than marking a failed
   stage `UNSTABLE` without agreement.
3. Use Jenkins-managed credentials in the narrowest `withCredentials`
   scope; use single-quoted Groovy shell scripts so the shell expands
   secrets, not Groovy interpolation. Isolate untrusted PRs from credential
   jobs and internal networks. Verify plugin and shared-library availability
   before using their steps. For GitHub Multibranch builds, review fork
   discovery and trust settings in Jenkins itself; do not rely on
   Jenkinsfile conditions to protect an internally connected agent from
   automatic untrusted fork builds.
4. When SonarQube passes the shared trust and scanner checks, if using
   `waitForQualityGate abortPipeline: true`, check that the SonarQube
   webhook can reach Jenkins and bound the wait with a timeout. Otherwise
   use a verified fail-closed scanner gate; never silently skip it.
5. Validate with the target Jenkins Declarative linter when authorized,
   then run the project's build/tests. If the Jenkins controller or agent
   is unavailable, report syntax and runtime behavior as unverified.

See [Jenkinsfile guidance](https://www.jenkins.io/doc/book/pipeline/jenkinsfile/),
[Declarative syntax](https://www.jenkins.io/doc/book/pipeline/syntax/),
[credentials binding](https://www.jenkins.io/doc/pipeline/steps/credentials-binding/),
and [Declarative linter](https://www.jenkins.io/doc/book/pipeline/development/).
