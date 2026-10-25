# CROW (Continuous Remediation & Optimization Workflows)

CROW is a public package of agents and skills for agentic software
development. It supports brownfield architecture, application development,
Java, .NET, and PHP CI across GitHub Actions, Azure Pipelines, and Jenkins,
framework and dependency maintenance, accessible B.C. government UX, testing,
security review and remediation, and the project setup needed to use those
capabilities across repositories.

Crow is distributed through the [Agent Package Manager (APM)][APM] and as a
Copilot CLI plugin. The full package remains available, and curated
collections are available when a project needs only part of Crow.

The [Crow vision and capability governance](GOVERNANCE.md) draft describes
the principles used to decide which agents and skills belong in Crow.

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
apm install bcgov/crow/collections/starter-package#stable --global --target copilot
```

Install the [Security Remediation collection](collections/security-remediation/README.md)
for application security scanning and remediation:

```powershell
apm install bcgov/crow/collections/security-remediation#stable --global --target copilot
```

Install the complete Crow package when all capabilities are needed:

```powershell
apm install bcgov/crow#stable --global --target copilot
```

Replace `copilot` with `claude`, `codex`, or `cursor` for another client.
The `--global` option installs into the selected client's user profile rather
than copying Crow into every project.

The `stable` branch follows the latest published stable Crow release. It is
seeded after successful main-branch asset validation and advances only when a
stable release is published. To migrate an existing exact-tag global install
to this update stream, run the full-package command above once; future
`apm update --global --target copilot` runs can then follow published releases.
For an exact, reproducible install of this release, use:

```powershell
apm install bcgov/crow#v0.16.0 --global --target copilot
```

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
release bundles, and generates a Crow-owned MCP fragment. After a separate
preview and approval it can merge the selected servers into Copilot Global's
`mcp-config.json`, also used by VS Code Copilot sessions. VS Code may migrate
old profile entries there; Crow does not write `mcp.json` or `settings.json`.
The merge preserves existing entries and backs up changed files.
For other editors, use the portable configuration only when the editor
supports its schema; otherwise follow its native MCP setup flow. Setup never
collects credentials. When new servers are added, it points to Raven's
installed Windows or macOS credential setup script if available. When
Sonar MCP is already configured (`sonar` in the Raven catalog or
`sonar-mcp`) or selected during setup, it also sets up the local SonarScanner
CLI and .NET/MSBuild scanner when a compatible .NET SDK is available, checks official
stable releases during setup or maintenance, and asks before upgrades.

Setup state is user-local under `~/.crow/raven-setup` by default. Do not
commit it or put Raven credentials in a repository.

For Copilot users, setup offers once to install an optional user-level hook
for update reminders. If enabled, it checks Crow's stable release and any
bundled Raven or codebase-memory-mcp release recorded by Crow Setup on an agent
prompt at most once every 24 hours. It creates no scheduled task and never
installs updates automatically. **The hook does not track SonarScanner
releases.** Run the Raven Setup Agent directly to check scanner versions when
Sonar MCP is configured or selected during setup.

### 4. Verify the installation

Use the selected client's normal discovery commands:

```text
/agent
/skills list
```

## Choose a collection

- [Starter Package](collections/starter-package/README.md) — Raven setup,
  architecture and code review, application architecture and development,
  B.C. UX, application CI, project context, testing, and framework/dependency maintenance
  for daily brownfield work.
- [Security Remediation](collections/security-remediation/README.md) —
  Raven setup, architecture review and handoff, project context, security
  review, Sonar scanning, secure architecture, application development,
  testing, and remediation.

APM selectors control update behavior: `#stable` follows published releases,
while an exact version tag such as `#v0.16.0` remains fixed. Installing
`bcgov/crow` without a ref follows the default branch and can include
unreleased commits. Collections use the same `stable` branch as the full
package.

## Agents

- [Crow CI Pipeline Agent](.apm/agents/crow-ci-pipelines.agent.md) — Assesses
  and builds Java/.NET/PHP CI across GitHub Actions, Azure Pipelines, and
  Jenkins. Inventories classic Azure builds and releases, analyzes supplied
  definition details, and creates Azure YAML and Declarative Jenkinsfiles.
- [Crow B.C. Government UX Agent](.apm/agents/crow-bcgov-ux.agent.md)
- [Crow Solution Architecture Agent](.apm/agents/crow-solution-architecture.agent.md)
- [Crow Architecture Review Agent](.apm/agents/crow-architecture-review.agent.md)
- [Crow Legacy Modernization Agent](.apm/agents/crow-legacy-modernization.agent.md) —
  Guides a legacy application through business and process discovery, portable
  baseline tests, approved architecture and implementation, and comparison
  without changing system-facing contracts or the datastore.
- [Crow Security & Dependency Review Agent](.apm/agents/crow-security-review.agent.md)
- [Crow Executive Summary Report Agent](.apm/agents/crow-executive-report.agent.md)
- [Crow Business Rule Documentation Agent](.apm/agents/crow-business-rule-documentation.agent.md)
- [Crow Security Remediation Agent](.apm/agents/crow-security-remediation.agent.md)
- [Crow Framework & Dependency Update Agent](.apm/agents/crow-framework-dependency-update.agent.md)
- [Crow Agent & Skill Authoring Agent](.apm/agents/crow-agent-skill-authoring.agent.md)
- [Crow Agent & Skill Review Agent](.apm/agents/crow-agent-skill-review.agent.md)
- [Crow Code Review Agent](.apm/agents/crow-code-review.agent.md) — Read-only,
  evidence-backed reviews of local diffs and hosted changes in GitHub or
  Azure DevOps, reporting only actionable findings.
- [Crow Simplification Review Agent](.apm/agents/crow-simplification-review.agent.md)
- [Crow Testing Agent](.apm/agents/crow-testing.agent.md)
- [Crow Raven Setup Agent](.apm/agents/crow-raven-setup.agent.md)

## Skills

- [**crow-ci-pipelines**](.apm/skills/crow-ci-pipelines/SKILL.md) —
  Java/.NET/PHP CI assessment, troubleshooting, and authoring with conditional
  [GitHub Actions](.apm/skills/crow-ci-pipelines/modules/github-actions.md),
  [Azure Pipelines](.apm/skills/crow-ci-pipelines/modules/azure-pipelines.md),
  and [Jenkins](.apm/skills/crow-ci-pipelines/modules/jenkins.md) guidance.
  Includes existing automated tests, applicable database-change artifacts,
  and application-version discovery when Sonar runs as part of CI.
- [**crow-bcgov-ux**](.apm/skills/crow-bcgov-ux/SKILL.md) — B.C. Design
  System and WCAG 2.2 AA UX guidance.
- [**crow-solution-architecture**](.apm/skills/crow-solution-architecture/SKILL.md) —
  B.C.-aligned solution architecture and stakeholder decisions. Interactive
  sessions can keep dated, context-specific choices in user-local
  `~/.crow/technology-preferences.json` after asking permission for each
  update; preferences never replace project constraints. See the
  [technology preferences guide](.apm/skills/crow-solution-architecture/modules/technology-preferences.md)
  for review, removal, and supported categories.
- [**crow-application-architecture**](.apm/skills/crow-application-architecture/SKILL.md) —
  Application boundaries, dependencies, platforms, and Zero Trust; technology
  modules include .NET, Java, and PHP.
- [**crow-application-development**](.apm/skills/crow-application-development/SKILL.md) —
  Production application code, persistence, integrations, and CI with .NET,
  Java, and PHP modules.
- [**crow-architecture-review**](.apm/skills/crow-architecture-review/SKILL.md) —
  Evidence-based architecture documentation.
- [**crow-legacy-modernization**](.apm/skills/crow-legacy-modernization/SKILL.md) —
  Cross-workflow phase gates for equivalent legacy application replacement.
  Available in the full Crow package, not the focused collections.
- [**crow-code-review**](.apm/skills/crow-code-review/SKILL.md) —
  Read-only local and hosted code review, also used after application changes.
- [**crow-business-rules**](.apm/skills/crow-business-rules/SKILL.md) —
  Business-rule extraction, reconciliation, and reporting.
- [**crow-executive-report**](.apm/skills/crow-executive-report/SKILL.md) —
  Executive security and architecture reporting.
- [**crow-project-context**](.apm/skills/crow-project-context/SKILL.md) —
  Safe public project memory and provider references.
- [**crow-raven-setup**](.apm/skills/crow-raven-setup/SKILL.md) — Selective
  Raven and codebase-memory-mcp setup and maintenance.
- [**crow-security-review**](.apm/skills/crow-security-review/SKILL.md) —
  Manual security, dependency, data-flow, PHP runtime, and issue-publication
  guidance.
- [**crow-framework-updates**](.apm/skills/crow-framework-updates/SKILL.md) —
  Supported runtime, SDK, and primary framework upgrades.
- [**crow-dependency-updates**](.apm/skills/crow-dependency-updates/SKILL.md) —
  Evidence-backed routine updates for libraries, plugins, and development
  tools.
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
- [**crow-testing**](.apm/skills/crow-testing/SKILL.md) — Reviewed feature
  scenarios organized by repository features, automated unit/integration tests
  (including PHP), and business-readable manual QA coverage; includes HTTP
  characterization and differential testing for REST/SOAP API modernization.
- [**crow-workflow-coordinator**](.apm/skills/crow-workflow-coordinator/SKILL.md) —
  Interactive guided workflow coordination, topological DAG scheduling, and
  approved command execution in isolated worktrees for complex engineering tasks.

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

The resulting archive is `build/bcgov-crow-0.16.0.zip`. See
[crow-release](.apm/skills/crow-release/SKILL.md) for release gates and
[crow-agent-skill-authoring](.apm/skills/crow-agent-skill-authoring/SKILL.md)
for the asset authoring workflow.
