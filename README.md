# CROW (Continuous Remediation & Optimization Workflows)

CROW is a collection of agents, skills, and detection modules for agentic software development. The intention is to set up this repo so that the agents and skills are available globally in VS Code or your favourite tool, so that they're available in any project you work on.

This repo is supposed to be used together with the RAVEN MCP server collection: [RAVEN](https://github.com/bcgov/raven)

## Available Agents

- **Architecture Review Agent** — Inspects a repository, analyzes its tech stack, and generates a verified `architecture.md` document in `/docs`.
- **Security & Dependency Review Agent** — Inspects repository frameworks, dependencies, known CVEs, security controls, and executes SonarQube scans to generate or update a `security-review.md` document in `/docs`. Includes formal evidence standards, false positive prevention rules, CVE provenance tagging, finding classification (Confirmed/Probable/Informational), and cross-file data flow tracing via codebase-memory-mcp.
- **Security Remediation Agent** — Remediates critical, high, and medium security vulnerabilities, framework/dependency technical debt, and test coverage gaps from `security-review.md`, then verifies and re-runs the security review.
- **Executive Summary Report Agent** — Synthesizes `/docs/architecture.md` and `/docs/security-review.md` into a high-level executive report in Markdown, a visual HTML dashboard (with charts, gauges, and heatmaps), and PDF output.

## Available Skills

- **sonar-scan** — Triggers when a code analysis, quality scan, or SonarQube / SonarCloud scan is requested using the `sonar-mcp` server.

## Security Review Detection Modules

Language-specific detection pattern modules that guide the Security & Dependency Review Agent's manual code analysis. These focus on vulnerabilities that SonarQube does not effectively detect (architectural issues, authorization logic, framework misconfigurations, cross-file data flows).

Located in `skills/security-review/modules/`:

- **auth-and-access-control** — Authorization gaps, IDOR, privilege escalation per framework (Spring, ASP.NET, Django, Express, Laravel, Rails, FastAPI)
- **framework-security-config** — Per-framework secure defaults and misconfigurations (CSRF, debug modes, middleware ordering, auto-escaping)
- **data-flow-sinks** — Cross-file entry-to-sink tracing protocol for SQL injection, command injection, SSRF, and path traversal
- **secrets-and-credentials** — Secrets in infrastructure files (Docker, CI/CD, Kubernetes, Terraform, Helm) that source-code scanners miss
- **deserialization-and-integrity** — Insecure deserialization per language, gadget chain reachability, unsigned data acceptance, CI/CD integrity
- **crypto-and-transport** — Context-appropriate algorithm assessment, key management lifecycle, TLS configuration, certificate validation
- **api-and-session-security** — Rate limiting, CORS, cookie flags, JWT implementation flaws, anti-forgery enforcement, HTTP verb constraints
- **frontend-spa-security** — React, Vue, Angular, Svelte: client-side XSS vectors, auth bypass, secret exposure via public env vars, SSR data leakage, state management security

## Templates

Report templates used by the agents:

- `templates/architecture.md` — Architecture document template
- `templates/security-review.md` — Security review template with YAML frontmatter for machine-readable metadata
- `templates/executive-report.md` — Executive summary Markdown template
- `templates/executive-report.html` — Visual HTML dashboard template with SVG charts, severity gauges, STRIDE heatmap, and print-to-PDF support

# Use in VS Code

## On Windows

Check out the Git repo into the `%USERPROFILE%\.copilot` folder to make the agents and skills available globally in VS Code.

## On macOS / Linux

Check out the Git repo into the `~/.copilot` folder to make the agents and skills available globally in VS Code.