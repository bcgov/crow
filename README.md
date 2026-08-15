# CROW (Continuous Remediation & Optimization Workflows)

CROW is a collection of agents, skills, and detection modules for agentic software development. The intention is to set up this repo so that the agents and skills are available globally in VS Code or your favourite tool, so that they're available in any project you work on.

This repo is supposed to be used together with the RAVEN MCP server collection: [RAVEN](https://github.com/bcgov/raven)

## MCP Prerequisites

CROW's architecture and security agents use **codebase-memory-mcp** for fast code intelligence, indexing, and cross-file analysis. Install it in your VS Code user profile (global scope) using [Install codebase-memory-mcp globally](vscode:mcp/install?%7B%22name%22%3A%22codebase-memory-mcp%22%2C%22command%22%3A%22npx%22%2C%22args%22%3A%5B%22-y%22%2C%22codebase-memory-mcp%22%5D%7D).

## Available Agents

- **Crow Architecture Review Agent** — Inspects a repository, analyzes its tech stack, and generates a verified `architecture.md` document in `/docs`.
- **Crow Security & Dependency Review Agent** — Inspects repository frameworks, dependencies, known CVEs, security controls, and executes SonarQube scans to generate or update a `security-review.md` document in `/docs`. Includes formal evidence standards, false positive prevention rules, CVE provenance tagging, finding classification (Confirmed/Probable/Informational), and cross-file data flow tracing via codebase-memory-mcp.
- **Crow Executive Summary Report Agent** — Synthesizes `/docs/architecture.md` and `/docs/security-review.md` into a high-level executive report in Markdown, a visual HTML dashboard (with charts, gauges, and heatmaps), and PDF output.
- **Crow Security Remediation Agent** — Remediates critical, high, and medium security vulnerabilities, framework/dependency technical debt, and test coverage gaps from `security-review.md`, then verifies and re-runs the security review.

## Available Skills

- **crow-architecture-review** — Bundles the architecture review workflow and document template.
- **crow-executive-report** — Bundles the executive report workflow, templates, schema, dashboard assets, and renderer.
- **crow-security-review** — Provides framework-specific detection modules and the security review document template.
- **crow-sonar-scan** — Triggers when a code analysis, quality scan, or SonarQube / SonarCloud scan is requested using the `sonar-mcp` server.

## Security Review Detection Modules

Language-specific detection pattern modules that guide the Crow Security & Dependency Review Agent's manual code analysis. These focus on vulnerabilities that SonarQube does not effectively detect (architectural issues, authorization logic, framework misconfigurations, cross-file data flows).

Located in `.apm/skills/crow-security-review/modules/`:

- **auth-and-access-control** — Authorization gaps, IDOR, privilege escalation per framework (Spring, ASP.NET, Django, Express, Laravel, Rails, FastAPI)
- **framework-security-config** — Per-framework secure defaults and misconfigurations (CSRF, debug modes, middleware ordering, auto-escaping)
- **data-flow-sinks** — Cross-file entry-to-sink tracing protocol for SQL injection, command injection, SSRF, and path traversal
- **secrets-and-credentials** — Secrets in infrastructure files (Docker, CI/CD, Kubernetes, Terraform, Helm) that source-code scanners miss
- **deserialization-and-integrity** — Insecure deserialization per language, gadget chain reachability, unsigned data acceptance, CI/CD integrity
- **crypto-and-transport** — Context-appropriate algorithm assessment, key management lifecycle, TLS configuration, certificate validation
- **api-and-session-security** — Rate limiting, CORS, cookie flags, JWT implementation flaws, anti-forgery enforcement, HTTP verb constraints
- **frontend-spa-security** — React, Vue, Angular, Svelte: client-side XSS vectors, auth bypass, secret exposure via public env vars, SSR data leakage, state management security

## Bundled Resources

Resources are owned by the skills that consume them:

- `.apm/skills/crow-architecture-review/architecture-template.md` — Architecture document template
- `.apm/skills/crow-security-review/security-review-template.md` — Security review template with YAML frontmatter for machine-readable metadata
- `.apm/skills/crow-security-review/modules/` — Language and framework-specific security detection modules
- `.apm/skills/crow-executive-report/` — Executive report template, schema, dashboard assets, and deterministic renderer

# Installation

CROW is distributed as both an APM package and a Copilot CLI plugin.

## Option 1: APM package (recommended)

APM installs Crow globally without requiring the Crow Git repository to occupy the Copilot profile directory. APM manages the package cache and installs the agents and skills into the user-level Copilot locations.

### On Windows

Install APM if it is not already available:

```powershell
irm https://aka.ms/apm-windows | iex
```

Install Crow globally:

```powershell
apm install bcgov/crow#v0.1.0 --global --target copilot
```

### On macOS / Linux

Install APM if it is not already available:

```bash
curl -sSL https://aka.ms/apm-unix | sh
```

Install Crow globally:

```bash
apm install bcgov/crow#v0.1.0 --global --target copilot
```

The `--global` installation keeps Crow's source and package cache separate from the Crow repository:

```text
<normal checkout, optional>       C:\Users\<user>\src\crow
APM package cache                 C:\Users\<user>\.apm
Global Copilot agents and skills C:\Users\<user>\.copilot
```

Verify the installation in Copilot CLI with `/agent` and `/skills list`, or restart VS Code and select a Crow agent from the agent picker.

To install a local development checkout without placing it in `.copilot`:

```powershell
apm install C:\path\to\crow --global --target copilot
```

## Option 2: Copilot CLI plugin

Install directly from the Crow repository:

```bash
copilot plugin install bcgov/crow
```

The plugin manifest uses the same `.apm` source files as the APM package, including the `crow-` prefixes. Verify with `copilot plugin list`, `/agent`, and `/skills list`.

## Building an APM/plugin bundle

From a Crow checkout, generate a versioned, integrity-checked plugin bundle:

```powershell
apm install
apm pack --archive --output build
```

The resulting archive is:

```text
build/bcgov-crow-0.1.0.zip
```

The archive contains a standard `plugin.json`, so it can be installed through APM or used as a Copilot CLI plugin bundle. Consumers can install it globally with APM:

```powershell
apm install .\build\bcgov-crow-0.1.0.zip --global --target copilot
```

For Copilot CLI, unpack and install the plugin directory:

```powershell
Expand-Archive .\build\bcgov-crow-0.1.0.zip -DestinationPath .\build\copilot
copilot plugin install .\build\copilot\bcgov-crow-0.1.0
```

## Do not use multiple Crow installations at once

An APM installation and an old manual Git checkout both install Crow's agents and skills at user scope. Installing both can create duplicate names with precedence that depends on the client and version. A manual Git checkout at `%USERPROFILE%\.copilot` also mixes Crow files with Copilot runtime state.

To check which method(s) are active:

- Inspect the APM installation with `apm` and check whether Crow agents are present in the user-level Copilot profile.
- A `.git` directory at `~/.copilot/.git` or `%USERPROFILE%\.copilot\.git` indicates the old manual-clone installation.

If multiple installations are present, remove all but one:

- Remove Crow through the APM installation workflow, or
- Move the old Git checkout out of `%USERPROFILE%\.copilot` / `~/.copilot`.

The bundled session-start hook warns only when it detects the old manual Git checkout, so APM's normal global installation does not produce a false duplicate warning.