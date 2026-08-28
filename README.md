# CROW (Continuous Remediation & Optimization Workflows)

CROW is a collection of agents, skills, and detection modules for agentic software development. The intention is to set up this repo so that the agents and skills are available globally in VS Code or your favourite tool, so that they're available in any project you work on.

This repo is supposed to be used together with the RAVEN MCP server collection: [RAVEN](https://github.com/bcgov/raven)

## MCP Prerequisites

CROW's architecture and security agents use **codebase-memory-mcp** for fast code intelligence, indexing, and cross-file analysis. Install it in your VS Code user profile (global scope) using [Install codebase-memory-mcp globally](vscode:mcp/install?%7B%22name%22%3A%22codebase-memory-mcp%22%2C%22command%22%3A%22npx%22%2C%22args%22%3A%5B%22-y%22%2C%22codebase-memory-mcp%22%5D%7D).

## Available Agents

- **Crow B.C. Government UX Agent** — Designs and implements new interfaces, or reviews and remediates existing applications, using the current B.C. Design System and WCAG 2.2 AA. Supports the frontend technologies covered by Crow while keeping user-journey design out of scope.
- **Crow Architecture Review Agent** — Inspects a repository, analyzes its tech stack, and generates a verified `architecture.md` document in `/docs`.
- **Crow Security & Dependency Review Agent** — Inspects repository frameworks, dependencies, known CVEs, security controls, and executes SonarQube scans to generate or update a `security-review.md` document in `/docs`. Includes formal evidence standards, false positive prevention rules, CVE provenance tagging, finding classification (Confirmed/Probable/Informational), and cross-file data flow tracing via codebase-memory-mcp.
- **Crow Executive Summary Report Agent** — Synthesizes `/docs/architecture.md` and `/docs/security-review.md` into a high-level executive report in Markdown, a visual HTML dashboard (with charts, gauges, and heatmaps), and PDF output.
- **Crow Security Remediation Agent** — Remediates critical, high, and medium security vulnerabilities, framework/dependency technical debt, and test coverage gaps from `security-review.md`, then verifies and re-runs the security review.
- **Crow Testing Agent** — Guides definition and implementation of automated unit and integration tests. Scans the codebase and docs first, then discusses interview-style surfacing concrete assumptions instead of asking blind questions; produces a reviewable `docs/testing/<feature>/<Feature>Scenarios.md` before writing code for integration tests and complex/critical unit tests. Technology-routed, starting with .NET/C#/F# and SQL Server. Includes a Model Tiers section (Lightweight/Mid-tier/Premium + a cross-family review rule) since CROW has no per-agent model pin. End-to-end testing and CI/CD pipeline authoring are out of scope for now.

## Available Skills

- **crow-bcgov-ux** — Technology-routed B.C. Design System and accessibility guidance for creating UX or reviewing and updating an existing application. Includes HTML/CSS/Razor, React-family, Vue-family, Angular, Svelte, and Blazor modules.
- **crow-architecture-review** — Bundles the architecture review workflow and document template.
- **crow-application-architecture** — Technology-routed application architecture guidance with current .NET and ASP.NET Core modules.
- **crow-application-development** — Technology-routed implementation guidance for .NET, ASP.NET Core, secure persistence, testing, CI, and containers.
- **crow-executive-report** — Bundles the executive report workflow, templates, schema, dashboard assets, and renderer.
- **crow-security-review** — Provides framework-specific detection modules and the security review document template.
- **crow-sonar-scan** — Triggers when a code analysis, quality scan, or SonarQube / SonarCloud scan is requested using the `sonar-mcp` server.
- **crow-testing** — Technology-routed guidance for defining and implementing automated unit and integration tests: testing philosophy (band-pass filter model, automation-candidate criteria), no-tests-yet discovery, scenario-doc-first workflow, and .NET/SQL Server-specific patterns. E2E testing is out of scope for now.

## Bundled Resources

Resources are owned by the skills that consume them:

- `.apm/skills/crow-bcgov-ux/` — B.C. government UX foundations, WCAG 2.2 AA acceptance criteria, existing-app review/remediation workflow, technology modules, and an optional `DESIGN.md` specification template
- `.apm/skills/crow-architecture-review/architecture-template.md` — Architecture document template
- `.apm/skills/crow-application-architecture/` — Context-routed architecture principles, .NET modules, and review evidence
- `.apm/skills/crow-application-development/` — Context-routed .NET implementation modules and review evidence
- `.apm/skills/crow-security-review/security-review-template.md` — Security review template with YAML frontmatter for machine-readable metadata
- `.apm/skills/crow-security-review/modules/` — Language and framework-specific security detection modules
- `.apm/skills/crow-executive-report/` — Executive report template, schema, dashboard assets, and deterministic renderer
- `.apm/skills/crow-testing/` — Testing philosophy and discovery modules, generic and .NET-specific unit/integration test guidance, reference deep-dives (property-based testing, legacy T-SQL harness, design-smell catalog), and `docs/testing/` templates (scenario doc, testing plan index, testability notes)

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
apm install bcgov/crow#v0.3.0 --global --target copilot
```

### On macOS / Linux

Install APM if it is not already available:

```bash
curl -sSL https://aka.ms/apm-unix | sh
```

Install Crow globally:

```bash
apm install bcgov/crow#v0.3.0 --global --target copilot
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
build/bcgov-crow-0.3.0.zip
```

The archive contains a standard `plugin.json`, so it can be installed through APM or used as a Copilot CLI plugin bundle. Consumers can install it globally with APM:

```powershell
apm install .\build\bcgov-crow-0.3.0.zip --global --target copilot
```

For Copilot CLI, unpack and install the plugin directory:

```powershell
Expand-Archive .\build\bcgov-crow-0.3.0.zip -DestinationPath .\build\copilot
copilot plugin install .\build\copilot\bcgov-crow-0.3.0
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