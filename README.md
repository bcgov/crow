# CROW (Continuous Remediation & Optimization Workflows)

CROW is a collection of agents, skills, and detection modules for agentic software development. The intention is to set up this repo so that the agents and skills are available globally in VS Code or your favourite tool, so that they're available in any project you work on.

This repo is supposed to be used together with the RAVEN MCP server collection: [RAVEN](https://github.com/bcgov/raven)

## MCP Prerequisites

CROW's architecture and security agents use **codebase-memory-mcp** for fast code intelligence, indexing, and cross-file analysis. Install it in your VS Code user profile (global scope) using [Install codebase-memory-mcp globally](vscode:mcp/install?%7B%22name%22%3A%22codebase-memory-mcp%22%2C%22command%22%3A%22npx%22%2C%22args%22%3A%5B%22-y%22%2C%22codebase-memory-mcp%22%5D%7D).

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

# Installation

CROW supports two install methods. **Pick one — do not use both at the same time** (see [Do not use both install methods at once](#do-not-use-both-install-methods-at-once) below).

## Option 1: Manual global clone (primary, fully supported)

Use this method for full functionality, including the executive report template renderer and the security detection modules, which currently rely on being read from a global `.copilot` folder path.

### On Windows

Check out the Git repo into the `%USERPROFILE%\.copilot` folder to make the agents and skills available globally in VS Code and the Copilot CLI.

### On macOS / Linux

Check out the Git repo into the `~/.copilot` folder to make the agents and skills available globally in VS Code and the Copilot CLI.

### Updating

```bash
git -C ~/.copilot pull
```

(`%USERPROFILE%\.copilot` on Windows.)

## Option 2: Install as a Copilot CLI plugin (secondary / experimental)

```bash
copilot plugin install bcgov/crow
```

To update:

```bash
copilot plugin update bcgov-crow
```

To uninstall:

```bash
copilot plugin uninstall bcgov-crow
```

This installs all four agents (`architecture-review`, `security-review`, `security-remediation`, `executive-report`) and both skills (`security-review`, `sonar-scan`). Verify with `copilot plugin list`, `/agent`, and `/skills list`.

> **Known limitation:** the agents in this repo read template and detection-module files from a hardcoded global path (`%USERPROFILE%\.copilot\templates\...` / `~/.copilot/skills/security-review/modules/...`). These paths are only guaranteed to resolve under the manual-clone method (Option 1). If you install purely as a plugin, verify these paths still resolve for your CLI version before relying on `executive-report` rendering or agent-driven security remediation — otherwise use Option 1.

## Do not use both install methods at once

If you already have crow manually cloned into `~/.copilot` and then also install the `bcgov-crow` plugin (or vice versa), both sources will define agents and skills with the **same file names**. GitHub's docs describe dedup/precedence rules based on config level (repo > user > org > enterprise), but a manual clone and a plugin install both resolve to the **user level**, so this is a same-level name collision — precedence between them is **not guaranteed**, and duplicate entries have been reported upstream in the CLI (see [github/copilot-cli#530](https://github.com/github/copilot-cli/issues/530)).

To check which method(s) are active:

- Run `copilot plugin list` to see if `bcgov-crow` is installed.
- Check whether `~/.copilot/agents/architecture-review.agent.md` (or `%USERPROFILE%\.copilot\agents\architecture-review.agent.md`) exists on disk — if so, the manual clone is also present.

If both are present, a warning is printed at the start of your Copilot CLI session (via a bundled `sessionStart` hook). To resolve it, either:

- Remove the manual clone (delete the `crow` checkout from `~/.copilot`), and keep using the plugin, **or**
- Uninstall the plugin (`copilot plugin uninstall bcgov-crow`) and keep using the manual clone.

Remember that updates are independent per method — updating one does not update the other.