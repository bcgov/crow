---
name: security-review
description: 'Provides language- and framework-specific detection pattern modules that guide manual security code review — authorization gaps, framework misconfigurations, cross-file data-flow tracing, secrets in infrastructure files, deserialization risks, crypto/transport issues, API/session security flaws, and frontend SPA security. Use when reviewing a repository for security vulnerabilities that automated SAST tools (like SonarQube) do not effectively detect.'
---

# Security Review Detection Modules

This skill bundles the detection pattern modules used by the **Security & Dependency Review Agent** and the **Security Remediation Agent** to guide manual code analysis for vulnerability classes that SonarQube and similar SAST tools miss (architectural issues, authorization logic, framework misconfigurations, cross-file data flows).

## When to use this skill

Load the relevant module(s) below when performing a manual security review or remediating a finding, based on the target repository's tech stack and the vulnerability class in question. Each module documents concrete per-framework patterns (Spring, ASP.NET, Django, Express, Laravel, Rails, FastAPI, React, Vue, Angular, Svelte, etc.).

## Bundled modules

Located in `modules/`:

- **`modules/auth-and-access-control.md`** — Authorization gaps, IDOR, privilege escalation per framework.
- **`modules/framework-security-config.md`** — Per-framework secure defaults and misconfigurations (CSRF, debug modes, middleware ordering, auto-escaping).
- **`modules/data-flow-sinks.md`** — Cross-file entry-to-sink tracing protocol for SQL injection, command injection, SSRF, and path traversal.
- **`modules/secrets-and-credentials.md`** — Secrets in infrastructure files (Docker, CI/CD, Kubernetes, Terraform, Helm) that source-code scanners miss.
- **`modules/deserialization-and-integrity.md`** — Insecure deserialization per language, gadget chain reachability, unsigned data acceptance, CI/CD integrity.
- **`modules/crypto-and-transport.md`** — Context-appropriate algorithm assessment, key management lifecycle, TLS configuration, certificate validation.
- **`modules/api-and-session-security.md`** — Rate limiting, CORS, cookie flags, JWT implementation flaws, anti-forgery enforcement, HTTP verb constraints.
- **`modules/frontend-spa-security.md`** — React, Vue, Angular, Svelte: client-side XSS vectors, auth bypass, secret exposure via public env vars, SSR data leakage, state management security.

## How to use

1. Identify the repository's tech stack (languages, frameworks, infra-as-code tooling).
2. Read the module(s) that match the vulnerability class or framework under review.
3. Apply the documented detection patterns during manual code inspection, cross-referencing findings with what automated scans already caught to avoid duplicate work.
4. When remediating, consult the same module(s) to ensure fixes implement the framework-recommended secure pattern rather than an ad hoc one.

> **Note:** The `architecture-review`, `security-review`, and `security-remediation` agents in this repo currently reference these modules via a hardcoded global path (`~/.copilot/skills/security-review/modules/` or `%USERPROFILE%\.copilot\skills\security-review\modules\`), which assumes crow has been cloned into the global `~/.copilot` folder. If you installed crow purely as a plugin, verify this path still resolves for your CLI version before relying on agent-driven security remediation.
