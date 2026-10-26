# Canonical Crow Orchestration Workflows

This guide outlines detailed execution plans for standard enterprise workflows orchestrated by `crow-workflow-coordinator`.

## Workflow 1: End-to-End Security Audit & Remediation

### Goal
Audit an enterprise application for security vulnerabilities, synthesize findings into SARIF, automatically remediate high-confidence issues in an isolated worktree, verify fixes with tests, and produce an executive review report.

### Nodes and Dependencies
1. **Node `ctx` (Read-only)**: Invoke `crow-project-context` to inspect project language, runtime, build tools, and database connections.
   - Outputs: Context brief, technology classification.
2. **Node `sonar` (Read-only)**: Invoke `crow-sonar-scan` to run static security scan via SonarQube/SonarCloud.
   - Depends on: `ctx`.
   - Concurrency: Runs concurrently with `sec_review`.
3. **Node `sec_review` (Read-only)**: Invoke `crow-security-review` across the 17 security modules (auth, data-flow sinks, deserialization).
   - Depends on: `ctx`.
   - Concurrency: Runs concurrently with `sonar`.
4. **Node `barrier_synthesis` (Join Barrier)**: Converge scan and review findings; run [`ConvertTo-CrowSecurityIssues.ps1`](../../crow-security-review/scripts/ConvertTo-CrowSecurityIssues.ps1) to produce unified `issues.sarif`.
   - Depends on: `sonar`, `sec_review`.
5. **Node `remediate` (Mutation)**: Invoke the [crow-security-remediation agent](../../../agents/crow-security-remediation.agent.md) in an isolated worktree (`.worktrees/task-sec-remediate`) to patch verified vulnerabilities.
   - Depends on: `barrier_synthesis`.
   - Constraints: Must not commit to `main`; modifies only files listed in `mutation_targets`.
6. **Node `verify_tests` (Verification)**: Run project unit tests and [`Test-CrowSecurityRemediationScopes.Tests.ps1`](../../crow-agent-skill-authoring/scripts/Test-CrowSecurityRemediationScopes.Tests.ps1).
   - Depends on: `remediate`.
   - Verifier: `mvn test` / `dotnet test` / `npm test` exit code 0.
7. **Node `audit_diff` (Verification)**: Run `crow-code-review` on git diff between worktree and base.
   - Depends on: `verify_tests`.
8. **Node `report` (Read-only)**: Run `crow-executive-report` ([`render-report.ps1`](../../crow-executive-report/render-report.ps1)) to publish the final HTML executive summary.
   - Depends on: `audit_diff`.

---

## Workflow 2: Legacy Service Modernization

### Goal
Modernize a legacy Java EE / Oracle PL/SQL or .NET 4.x service into a modern containerized service with full behavioral parity.

### Nodes and Dependencies
1. **Node `context` (Read-only)**: `crow-project-context` catalogs database schemas, stored procedures, and external interfaces.
2. **Node `rules` (Read-only)**: `crow-business-rules` extracts deterministic business rules from legacy controllers and procedures. Emits `business-rules.md` and Mermaid workflow diagrams.
   - Depends on: `context`.
3. **Node `baseline` (Mutation)**: `crow-testing` writes characterization tests capturing existing legacy HTTP / stored procedure behavior.
   - Depends on: `rules`.
4. **Node `modernize` (Mutation)**: `crow-legacy-modernization` implements modern service endpoints matching the business rule specifications.
   - Depends on: `baseline`.
5. **Node `parity` (Verification)**: Run differential testing comparing legacy baseline responses against modernized service responses.
   - Depends on: `modernize`.
   - Verifier: 100% response payload equivalence on canonical test vectors.
6. **Node `signoff` (Read-only)**: `crow-executive-report` generates modernization audit artifact.
   - Depends on: `parity`.
