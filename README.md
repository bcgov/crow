# CROW (Continuous Remediation & Optimization Workflows)

CROW is a public package of agents and skills for agentic software
development. It supports brownfield architecture, application development,
accessible B.C. government UX, testing, security review and remediation, and
the project setup needed to use those capabilities across repositories.

Crow is distributed through the [Agent Package Manager (APM)][APM] and as a
Copilot CLI plugin. The full package remains available, and curated
collections are available when a project needs only part of Crow.

[APM]: https://github.com/microsoft/apm
[Raven]: https://github.com/bcgov/raven
[codebase-memory-mcp]: https://github.com/bcgov/codebase-memory-mcp

## Install Crow

### 1. Install APM

On Windows:

```powershell
irm https://aka.ms/apm-windows | iex
```

On macOS or Linux:

```bash
curl -sSL https://aka.ms/apm-unix | sh
```

### 2. Install a package

Install the [Starter Package](collections/starter-package/README.md) for
daily brownfield development:

```powershell
apm install bcgov/crow/collections/starter-package#v0.10.3 --global --target copilot
```

Install the [Security Remediation collection](collections/security-remediation/README.md)
for application security scanning and remediation:

```powershell
apm install bcgov/crow/collections/security-remediation#v0.10.3 --global --target copilot
```

Install the complete Crow package when all capabilities are needed:

```powershell
apm install bcgov/crow#v0.10.3 --global --target copilot
```

Replace `copilot` with `claude`, `codex`, or `cursor` for another client.
The `--global` option installs into the selected client's user profile rather
than copying Crow into every project.

### Direct Copilot CLI plugin

Copilot CLI users can install the complete Crow plugin directly instead of
using APM:

```bash
copilot plugin install bcgov/crow
```

Verify the plugin and its assets with:

```text
copilot plugin list
/agent
/skills list
```

### 3. Set up Raven and code intelligence

After installation, invoke the **[Crow Raven Setup Agent](.apm/agents/crow-raven-setup.agent.md)**
first:

```text
/agent Crow Raven Setup Agent
```

The guided setup checks prerequisites, lets you choose Raven capability
groups or [codebase-memory-mcp], pins server versions, verifies attested
release bundles, and writes a Crow-owned MCP configuration fragment without
overwriting existing client configuration or collecting credentials. It also
checks for available Crow package updates without applying them.

Setup state is user-local under `~/.crow/raven-setup` by default. Do not
commit it or put Raven credentials in a repository.

### 4. Verify the installation

Use the selected client's normal discovery commands:

```text
/agent
/skills list
```

## Choose a collection

- [Starter Package](collections/starter-package/README.md) — Raven setup,
  architecture review, application architecture and development, B.C. UX,
  project context, and testing for daily brownfield work.
- [Security Remediation](collections/security-remediation/README.md) —
  Raven setup, architecture review and handoff, project context, security
  review, Sonar scanning, secure architecture, application development,
  testing, and remediation.

Collections use the same Crow release tag as the full package. Existing
`apm install bcgov/crow#...` installations continue to receive the full
package and are unaffected by the collections.

## Agents

- [Crow B.C. Government UX Agent](.apm/agents/crow-bcgov-ux.agent.md)
- [Crow Solution Architecture Agent](.apm/agents/crow-solution-architecture.agent.md)
- [Crow Architecture Review Agent](.apm/agents/crow-architecture-review.agent.md)
- [Crow Security & Dependency Review Agent](.apm/agents/crow-security-review.agent.md)
- [Crow Executive Summary Report Agent](.apm/agents/crow-executive-report.agent.md)
- [Crow Business Rule Documentation Agent](.apm/agents/crow-business-rule-documentation.agent.md)
- [Crow Security Remediation Agent](.apm/agents/crow-security-remediation.agent.md)
- [Crow Agent & Skill Authoring Agent](.apm/agents/crow-agent-skill-authoring.agent.md)
- [Crow Agent & Skill Review Agent](.apm/agents/crow-agent-skill-review.agent.md)
- [Crow Simplification Review Agent](.apm/agents/crow-simplification-review.agent.md)
- [Crow Testing Agent](.apm/agents/crow-testing.agent.md)
- [Crow Raven Setup Agent](.apm/agents/crow-raven-setup.agent.md)

## Skills

- [**crow-bcgov-ux**](.apm/skills/crow-bcgov-ux/SKILL.md) — B.C. Design
  System and WCAG 2.2 AA UX guidance.
- [**crow-solution-architecture**](.apm/skills/crow-solution-architecture/SKILL.md) —
  B.C.-aligned solution architecture and stakeholder decisions.
- [**crow-application-architecture**](.apm/skills/crow-application-architecture/SKILL.md) —
  Application boundaries, dependencies, platforms, and Zero Trust.
- [**crow-application-development**](.apm/skills/crow-application-development/SKILL.md) —
  Production application code, persistence, integrations, and CI.
- [**crow-architecture-review**](.apm/skills/crow-architecture-review/SKILL.md) —
  Evidence-based architecture documentation.
- [**crow-business-rules**](.apm/skills/crow-business-rules/SKILL.md) —
  Business-rule extraction, reconciliation, and reporting.
- [**crow-executive-report**](.apm/skills/crow-executive-report/SKILL.md) —
  Executive security and architecture reporting.
- [**crow-project-context**](.apm/skills/crow-project-context/SKILL.md) —
  Safe public project memory and provider references.
- [**crow-raven-setup**](.apm/skills/crow-raven-setup/SKILL.md) — Selective
  Raven and codebase-memory-mcp setup and maintenance.
- [**crow-security-review**](.apm/skills/crow-security-review/SKILL.md) —
  Manual security, dependency, data-flow, and issue-publication guidance.
- [**crow-sonar-scan**](.apm/skills/crow-sonar-scan/README.md) — Sonar scan
  execution through the Sonar MCP server.
- [**crow-simplification-review**](.apm/skills/crow-simplification-review/SKILL.md) —
  Opt-in review for unnecessary complexity and tracked Crow debt.
- [**crow-agent-skill-authoring**](.apm/skills/crow-agent-skill-authoring/SKILL.md) —
  Crow asset creation, packaging, and release hygiene.
- [**crow-agent-skill-review**](.apm/skills/crow-agent-skill-review/SKILL.md) —
  Read-only Crow asset quality and release review.
- [**crow-release**](.apm/skills/crow-release/SKILL.md) — Versioned package
  preparation, validation, and publication.
- [**crow-testing**](.apm/skills/crow-testing/SKILL.md) — Unit and integration
  testing strategy and implementation.

## Optional reporting prerequisite

The [Crow Business Rule Documentation Agent](.apm/agents/crow-business-rule-documentation.agent.md)
requires a preinstalled Mermaid CLI (`mmdc`) only when diagrams are needed:

```powershell
npm install -g @mermaid-js/mermaid-cli
```

## Local development and release

From a Crow checkout, install dependencies and build a versioned bundle:

```powershell
apm install
apm pack --archive --output build
```

The resulting archive is `build/bcgov-crow-0.10.3.zip`. See
[crow-release](.apm/skills/crow-release/SKILL.md) for release gates and
[crow-agent-skill-authoring](.apm/skills/crow-agent-skill-authoring/SKILL.md)
for the asset authoring workflow.
