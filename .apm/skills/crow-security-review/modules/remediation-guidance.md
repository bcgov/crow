# Security Remediation Guidance

Load queue guidance only for security-remediation scopes, not update-only
compatibility scopes. The summary section also applies to update-only runs.
The remediation agent owns canonical scope resolution, source-document gates,
queue selection, approvals, and completion. Apply only the active queue's
guidance and independently verified findings; ticket modes remain limited to
their validated ticket backlog.

## Vulnerability fixes (Queues B and C)

1. Select detection modules through the [skill router](../SKILL.md). For
   stateful findings, use
   [stateful operations](../../crow-application-development/modules/stateful-operations.md)
   and its linked test scenarios.
2. Load [platform-data-and-proofs.md](platform-data-and-proofs.md) when the
   finding concerns shared/canonical data, external decisions, digital proofs,
   or identity assurance. For each finding in Queue B and Queue C:
   - **Verification Check:** If the finding is tagged as `Probable`, verify the exploit path using `trace_path` or manual code inspection. If existing code or framework auto-escaping/parameterization already mitigates the issue (false positive), document this and skip modifying the code.
   - **Remediation Execution:** Apply secure-by-default fixes following the pattern module guidance. For platform/proof findings, do not broaden data access or weaken assurance as a workaround; preserve contract ownership/versioning, timeout/retry/idempotency/cancellation, safe fallback, and privacy-preserving audit context:
     - Access control and injection: use
       [authorization](auth-and-access-control.md),
       [entry-to-sink](data-flow-sinks.md), and
       [API/session](api-and-session-security.md) patterns.
     - Cryptography and credentials: use the context-appropriate controls in
       [crypto-and-transport.md](crypto-and-transport.md) and
       [secrets-and-credentials.md](secrets-and-credentials.md).
     - Frontend/SPA rendering and token/state handling: use
       [frontend-spa-security.md](frontend-spa-security.md).
     - Headers and production configuration: use
       [framework-security-config.md](framework-security-config.md).
     - Security-event auditing: use
       [security-logging-and-audit.md](security-logging-and-audit.md).
       Exception responses and application diagnostics use the
       [diagnostics module](../../crow-application-development/modules/application-diagnostics.md).
3. If fixing a verified finding requires a framework/runtime migration, load
   `crow-framework-updates` for migration planning and verification. Keep the
   finding, evidence, and completion status in this security workflow.
4. If a finding requires a third-party dependency change, change only the
   package versions needed to resolve that finding; do not run the routine
   dependency backlog here.

---

## Security hardening

1. Perform architectural security refactoring aligned with the applicable architecture document. In a monorepo, make changes within the matching service scope unless the change is explicitly documented as shared infrastructure:
   - Refactor monolithic or tightly coupled authentication/authorization handlers into dedicated middleware or guards.
   - Strengthen trust boundary validation across service interfaces and API controllers.
   - Centralize error handling at the handling boundary using
     [application diagnostics](../../crow-application-development/modules/application-diagnostics.md);
     preserve visible failure and restricted diagnostic detail rather than
     swallowing exceptions. Use the security-audit module for audit events.
   - Enforce secure configuration defaults across web framework bootstrap files.

---

## Security-control tests (Queue E)

1. Inspect the repository's test framework and run its coverage reporting.
   Compare production enforcement points and test paths against the
   [security-control matrix](security-control-assurance.md).
2. Use [crow-testing](../../crow-testing/SKILL.md) to design and implement
   focused unit, integration, and negative-case tests for the in-scope gaps.
   Follow repository conventions and architectural boundaries; do not expand
   a ticket fix into unrelated coverage work.
3. Re-run tests and coverage, verify the production controls and real
   framework wiring, and report starting/final aggregate coverage separately.
   Apply a percentage goal only when established by the target project;
   do not impose a universal 40% threshold or use percentage as the completion
   proxy.

---

## Critical and High fix challenge

For a `Critical` or `High` vulnerability fix, challenge the changed control
before declaring it resolved: trace the original attacker path through the
changed enforcement point and relevant callers, look for a plausible bypass
or an unaffected entry point, and run a negative regression test with
isolated fixtures in the local test suite where reproducible. When the same
test can safely run against both revisions, verify and record that it fails
against the vulnerable revision and passes against the fixed revision;
otherwise disclose the unavailable comparison without implying it passed.
Do not probe a deployed service without separate, specific authorization.
When an independent read-only reviewer is available, use a fresh context that
excludes the original reviewer's analysis and prior review output. Give it the
bounded bug statement, patch, affected callers, test evidence, and a specific
verification question; withhold the original reviewer's rationale, severity
judgment, and disposition until its source-first assessment is returned. A
separate reviewer or session does not by itself establish fresh context;
disclose when context isolation cannot be verified. Otherwise perform this
adversarial pass yourself and state that no independent review ran. Verify
objections against current source and tests; fix and retest confirmed
bypasses. A scanner clearing the original finding is not proof that every
entry point is protected. Do not send payloads to production or treat the
challenger as a substitute for the remediation agent's security re-review.

---

## Remediation summary

Present a comprehensive summary to the user:
- **Target Remediation Scope Executed:** Report canonical `targetScope`
  (`framework-upgrades`, `vulnerabilities`, `dependencies`, `refactoring`,
  `test-coverage`, `security-tickets-selected`, `security-tickets-all`, or
  `all`).
- **Compatibility Notice:** Identify any deprecated update-only input alias
  and recommend the dedicated update agent for routine
  or recurring maintenance.
- **Security Tickets:** List the configured provider, selected ticket IDs,
  closed/resolved tickets, and tickets left open with reasons.
- **Security Vulnerabilities Fixed:** List of resolved `Critical`, `High`, and `Medium` findings (noting `Confirmed` vs `Probable` verified).
- **Dependencies & Frameworks Upgraded:** List of updated packages and manifest files.
- **Security Refactoring & Code Hardening:** Summary of architectural security refactoring performed.
- **Security-Control Assurance:** Closed matrix gaps, test levels, negative
  cases, and starting versus final aggregate coverage.
- **Build & Test Verification:** Test pass count and status.
- **Re-Run Status:** For update-only `framework-upgrades` and `dependencies`
  scopes, report security re-review and security-review document/frontmatter
  refresh as **Not Applicable** without requesting confirmation. For `all` and
  security-remediation scopes, report confirmation that the applicable
  security-review document(s) and frontmatter were refreshed and verified; in a
  monorepo, list each service document explicitly.
