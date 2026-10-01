---
name: crow-security-review
description: 'Provides detection modules for manual security review, including authorization, framework configuration, cross-file data flow, secrets, deserialization, crypto, API/session and SPA security, LLM prompt injection, second-order injection, and Markdown security. Use with the Crow Security & Dependency Review Agent or Crow Security Remediation Agent.'
---

# Security Review Detection Modules

This skill bundles the detection pattern modules used by the **Crow Security & Dependency Review Agent** and the **Crow Security Remediation Agent** to guide manual code analysis for vulnerability classes that SonarQube and similar SAST tools miss (architectural issues, authorization logic, framework misconfigurations, cross-file data flows).

Before external resource discovery, load
[`../crow-project-context/SKILL.md`](../crow-project-context/SKILL.md) and read
the target repository's `crow.config`. Use its provider references to find
pipelines, work items, related repositories, and documentation. When a user
supplies a resource URL, update the manifest only with a verified public
descriptor or symbolic reference; never write an internal URL or secret.

Load [`modules/security-issue-publishing.md`](modules/security-issue-publishing.md)
when offering to publish validated findings to GHAS or a ticketing system, or
when the remediation agent is sourcing work from security tickets. It owns the
canonical SARIF format, destination/config discovery, consent, deduplication,
labeling, and ticket lifecycle contract.

## When to use this skill

Load the relevant module(s) below when performing a manual security review or remediating a finding, based on the target repository's tech stack and the vulnerability class in question. Each module documents concrete per-framework patterns (Spring, ASP.NET, Django, Express, Laravel, Rails, FastAPI, React, Vue, Angular, Svelte, etc.).

## Bundled modules

Located in `modules/`:

- **`security-review-template.md`** — Security review document structure with YAML frontmatter for machine-readable metadata.
- **`modules/auth-and-access-control.md`** — Authorization gaps, IDOR, privilege escalation per framework.
- **`modules/framework-security-config.md`** — Per-framework secure defaults and misconfigurations (CSRF, debug modes, middleware ordering, auto-escaping).
- **`modules/data-flow-sinks.md`** — Cross-file entry-to-sink tracing protocol for SQL injection, command injection, SSRF, and path traversal.
- **`modules/secrets-and-credentials.md`** — Secrets in infrastructure files (Docker, CI/CD, Kubernetes, Terraform, Helm) that source-code scanners miss.
- **`modules/deserialization-and-integrity.md`** — Insecure deserialization per language, gadget chain reachability, unsigned data acceptance, CI/CD integrity.
- **`modules/crypto-and-transport.md`** — Context-appropriate algorithm assessment, key management lifecycle, TLS configuration, certificate validation.
- **`modules/api-and-session-security.md`** — Rate limiting, CORS, cookie flags, JWT implementation flaws, anti-forgery enforcement, HTTP verb constraints.
- **`modules/security-logging-and-audit.md`** — Security-event lifecycle coverage, authoritative audit points, attribution, correlation, redaction, retention, and alerting boundaries.
- **`modules/security-control-assurance.md`** — Security-control test matrix, real framework-boundary coverage, negative cases, and tracked CI gate enforcement.
- **`modules/finding-synthesis-and-validation.md`** — Independent adjudication, cross-domain themes, evidence-backed attack paths, and deterministic component remediation priority.
- **`modules/stride-threat-model.md`** — Required evidence-backed STRIDE ratings and the machine-readable synthesis/report handoff.
- **`modules/frontend-spa-security.md`** — React, Vue, Angular, Svelte: client-side XSS vectors, auth bypass, secret exposure via public env vars, SSR data leakage, state management security.
- **`modules/llm-prompt-and-markdown-security.md`** — Direct and stored/second-order prompt injection, RAG and tool-calling trust boundaries, insecure model-output handling, excessive agency, and Markdown/frontmatter/rendering risks.
- **`modules/security-issue-publishing.md`** — SARIF-based GHAS and ticket publishing, `crow-security` labeling, destination memory, deduplication, and ticket-driven remediation.

The deterministic publisher input/output converter is
`scripts/ConvertTo-CrowSecurityIssues.ps1`; its tests are
`scripts/ConvertTo-CrowSecurityIssues.Tests.ps1`.
The deterministic synthesis and consistency tools are
`scripts/New-CrowSecuritySynthesis.ps1`,
`scripts/Test-CrowSecurityReviewOutput.ps1`, and
`scripts/Find-CrowSecurityCiGates.ps1`; their tests are
`scripts/New-CrowSecuritySynthesis.Tests.ps1`.
- **`modules/platform-data-and-proofs.md`** — Conditional checks for data minimization, scoped questions, pairwise correlation, digital proofs, assurance-level fallback, and privacy-preserving audit context.
- **`../crow-application-architecture/modules/zero-trust.md`** — Conditional checks for protected resources, explicit access decisions, least privilege, revocation, degradation, exceptions, and evidence-backed outcomes.

## How to use

1. Identify the repository's tech stack, LLM/agent integrations, document ingestion/rendering pipelines, and infrastructure-as-code tooling.
2. Read the module(s) that match the vulnerability class or framework under review.
3. Apply the documented detection patterns during manual code inspection, cross-referencing findings with what automated scans already caught to avoid duplicate work.
4. For every security review, read `modules/stride-threat-model.md` and populate
   both the security-review STRIDE table and the synthesis JSON `stride` array.
   The executive report consumes this structured data; a prose-only summary is
   not a substitute.
5. Load `security-logging-and-audit.md` when the application authenticates,
   authorizes, manages credentials/tokens, performs privileged administration,
   or changes sensitive state.
6. Load `security-control-assurance.md` when security controls, test projects,
   or tracked CI/CD pipelines exist.
7. Load `finding-synthesis-and-validation.md` after the domain passes produce
   at least two findings that may share a root control, workflow, resource, or
   attacker path.
8. When a fresh validated `architecture-security-facts.json` exists beside the
   applicable architecture document, consume its facts and workflows before
   rediscovering architecture. Treat stale, inferred, or unknown facts as
   discovery hints and re-verify material claims.
9. When remediating, consult the same module(s) to ensure fixes implement the framework-recommended secure pattern rather than an ad hoc one.

Load `platform-data-and-proofs.md` only when the repository has a shared or
canonical data flow, an external decision/register dependency, or a digital
proof/assurance boundary. Load `../crow-application-architecture/modules/zero-trust.md`
when the repository has a meaningful identity, device, resource, transaction,
privileged, workload, network, API, external-decision, or cross-service trust
boundary. Apply routed modules to affected paths; do not report undocumented
policy as a confirmed vulnerability.

The `security-review` and `security-remediation` agents load these modules and the bundled `security-review-template.md` from this skill.
