# CROW (Continuous Remediation & Optimization Workflows)

CROW is a collection of agents, skills, and detection modules for agentic software development. The intention is to set up this repo so that the agents and skills are available globally in VS Code or your favourite tool, so that they're available in any project you work on.

This repo is supposed to be used together with the RAVEN MCP server collection: [RAVEN](https://github.com/bcgov/raven)

## MCP Prerequisites

CROW's architecture and security agents use **codebase-memory-mcp** for fast code intelligence, indexing, and cross-file analysis. Install it in your VS Code user profile (global scope) using [Install codebase-memory-mcp globally](vscode:mcp/install?%7B%22name%22%3A%22codebase-memory-mcp%22%2C%22command%22%3A%22npx%22%2C%22args%22%3A%5B%22-y%22%2C%22codebase-memory-mcp%22%5D%7D).

## Business rule reporting prerequisites

The **Crow Business Rule Documentation Agent** pre-renders diagrams with a preinstalled Mermaid CLI (`mmdc`). Install it once with `npm install -g @mermaid-js/mermaid-cli`, or pass `-MermaidCliPath <path to mmdc>` to the renderer. The renderer never invokes `npx` and never downloads a package while running, so a run that needs diagrams fails with an actionable message until `mmdc` is available. Reports without diagrams need no Mermaid CLI.

Each reviewed repository commits `docs/business-rules-data.json` next to the two generated documents. That file is canonical: it is the snippet-free input both documents are rendered from and the permanent identifier ledger. Regeneration compares the new data against the previously committed copy, so a rule identifier cannot disappear, silently reactivate, or be reused for a different rule. That comparison is mandatory: once `docs/business-rules.md` or `docs/business-rules.html` exists, the renderer refuses to run without the previously committed data file, which is extracted byte for byte by the bundled `Export-PreviousBusinessRuleData.ps1`. Do not hand-edit the generated Markdown or HTML; change the data and re-render.

## Available Agents

- **Crow B.C. Government UX Agent** — Designs and implements new interfaces, or reviews and remediates existing applications, using the current B.C. Design System and WCAG 2.2 AA. Supports the frontend technologies covered by Crow while keeping user-journey design out of scope.
- **Crow Architecture Review Agent** — Inspects a repository and creates or updates verified architecture documentation under `docs/`, with conditional platform-role, reuse, custodianship, contract, degradation, and Zero Trust resource-protection assessment plus service-scoped documents and an index for monorepos.
- **Crow Security & Dependency Review Agent** — Inspects repository frameworks, dependencies, known CVEs, security controls, and executes SonarQube scans to generate or update a `security-review.md` document in `/docs`. Includes formal evidence standards, false positive prevention rules, CVE provenance tagging, the approved Critical through Informational severity scheme, conditional data/proof checks, and cross-file data flow tracing via codebase-memory-mcp.
- **Crow Executive Summary Report Agent** — Synthesizes `/docs/architecture.md` and `/docs/security-review.md` into a high-level executive report in Markdown, a visual HTML dashboard (with charts, gauges, and heatmaps), and PDF output.
- **Crow Business Rule Documentation Agent** — Documents the business rules one application or service actually enforces, reconciles them with available guides and training material, and generates `docs/business-rules.md` plus a self-contained accessible HTML report with pre-rendered Mermaid diagrams, facet filtering, and stable rule identifiers.
- **Crow Security Remediation Agent** — Remediates critical, high, and medium security vulnerabilities, framework/dependency technical debt, and test coverage gaps from `security-review.md`, then verifies and re-runs the security review.
- **Crow Agent & Skill Authoring Agent** — Creates and updates Crow agents and skills using consistent boundaries, progressive context loading, deterministic tooling, public-release hygiene, and semantic versioning.
- **Crow Agent & Skill Review Agent** — Reviews Crow agents and skills for correctness, context and token efficiency, automation opportunities, knowledge/execution separation, semantic versioning, and public-release suitability.
- **Crow Simplification Review Agent** — Performs an opt-in, read-only application review for unnecessary complexity, simpler standard-library or native alternatives, and tracked Crow debt.
- **Crow Testing Agent** — Guides definition and implementation of automated unit and integration tests. Scans the codebase and docs first, then discusses interview-style surfacing concrete assumptions instead of asking blind questions; produces a reviewable `docs/testing/<feature>/<Feature>Scenarios.md` before writing code for integration tests and complex/critical unit tests, including conditional shared-service contracts and resilience scenarios. Technology-routed, starting with .NET/C#/F# and SQL Server. Its skill workflow includes model-tier and cross-family review guidance, safe hash-based updates for copied Crow test-utility templates, and no per-agent model pin. End-to-end testing and CI/CD pipeline authoring are out of scope for now.

## Available Skills

- **crow-bcgov-ux** — Technology-routed B.C. Design System and accessibility guidance for creating UX or reviewing and updating an existing application, including point-of-use decision explanations and clear degraded/async/offline/assisted states without journey design. Includes HTML/CSS/Razor, React-family, Vue-family, Angular, Svelte, and Blazor modules.
- **crow-architecture-review** — Routes repository classification, inspection, document generation or update, and deterministic output validation.
- **crow-application-architecture** — Technology-routed application architecture guidance with current .NET and ASP.NET Core modules plus conditional, technology-neutral platform alignment, reuse, and Zero Trust resource-protection guidance.
- **crow-application-development** — Technology-routed implementation guidance for .NET, ASP.NET Core, secure persistence, testing, CI, and containers.
- **crow-executive-report** — Bundles the executive report workflow, templates, schema, dashboard assets, and renderer.
- **crow-business-rules** — Routes business rule extraction, documentation reconciliation, and diagramming, and bundles the snippet-free data schema, report templates, accessible HTML assets, deterministic renderer, and tests.
- **crow-security-review** — Provides framework-specific detection modules and the security review document template.
- **crow-sonar-scan** — Triggers when a code analysis, quality scan, or SonarQube / SonarCloud scan is requested using the `sonar-mcp` server.
- **crow-agent-skill-authoring** — Guides consistent agent and skill creation or updates, with templates and deterministic package validation.
- **crow-agent-skill-review** — Provides the review rubric for context/token optimization, deterministic automation, public release, and knowledge/execution separation.
- **crow-simplification-review** — Reviews application changes or repositories for unnecessary complexity and reports `crow-debt:` markers without applying fixes.
- **crow-release** — Prepares, packages, checksums, and publishes Crow versions through GitHub Releases with an explicit user decision for major versions.
- **crow-testing** — Technology-routed guidance for defining and implementing automated unit and integration tests: testing philosophy (band-pass filter model, automation-candidate criteria), no-tests-yet discovery, scenario-doc-first workflow, .NET/SQL Server-specific patterns, and managed updates for copied Crow test-utility templates. E2E testing is out of scope for now.

## Bundled Resources

Resources are owned by the skills that consume them:

- `.apm/skills/crow-bcgov-ux/` — B.C. government UX foundations, WCAG 2.2 AA acceptance criteria, existing-app review/remediation workflow, technology modules, and an optional `DESIGN.md` specification template
- `.apm/skills/crow-architecture-review/architecture-template.md` — Architecture document template
- `.apm/skills/crow-application-architecture/` — Context-routed architecture principles, conditional platform-alignment/reuse and Zero Trust resource-protection guidance, and .NET modules
- `.apm/skills/crow-application-development/` — Context-routed .NET implementation modules
- `.apm/skills/crow-security-review/security-review-template.md` — Security review template with YAML frontmatter for machine-readable metadata
- `.apm/skills/crow-security-review/modules/` — Language and framework-specific security detection modules
- `.apm/skills/crow-executive-report/` — Executive report template, schema, dashboard assets, and deterministic renderer
- `.apm/skills/crow-business-rules/` — Business rule extraction, reconciliation, and diagramming modules, the `business-rules-data.json` schema and synthetic example, Markdown and HTML report templates, B.C.-aligned stylesheet and facet-filtering script, pinned Mermaid configuration, deterministic renderer and validator, and their tests
- `.apm/skills/crow-testing/` — Testing philosophy and discovery modules, generic and .NET-specific unit/integration test guidance, conditional shared-service contract/resilience scenarios, reference deep-dives (property-based testing, legacy T-SQL harness, design-smell catalog), `docs/testing/` templates (scenario doc, testing plan index, testability notes), deterministic hash-based synchronization for copied generator templates, and a maintainer-facing `MAINTENANCE.md` mapping ecosystem changes (new C#/.NET versions, analyzer coverage, test library upgrades) to the files that need updating
- `.apm/skills/crow-agent-skill-authoring/` — Authoring patterns, public-release guidance, templates, and deterministic validation
- `.apm/skills/crow-agent-skill-review/` — Agent and skill review rubric and review template
- `.apm/skills/crow-simplification-review/` — Application simplification review, Crow debt marker workflow, conventional debt-comment reporting, deterministic debt scanner, and the reusable `Crow-debt.md` ledger template
- `.apm/skills/crow-release/` — Semantic-version policy and deterministic version/package/release scripts

## Agent and skill authoring conventions

Crow separates knowledge from execution so agents load less context and mechanical work remains reproducible:

- agents own role, decisions, tool orchestration, failure behaviour, and completion gates;
- `SKILL.md` files are concise routers that load only relevant knowledge;
- modules own optional domain knowledge and acceptance criteria;
- templates own stable output shapes;
- scripts own deterministic validation, transformation, rendering, packaging, checksums, and release operations;
- authoring evidence stays outside `.apm/`, Git tracking, and release archives.

Existing routed application, UX, and security modules already follow the knowledge side of this pattern, while the executive-report renderer is an example of deterministic execution. When updating older large agents, prefer extracting reusable policy into routed modules and replacing repeated document checks or transformations with scripts rather than adding more unconditional prompt context.

Use the **Crow Agent & Skill Authoring Agent** to make changes, the **Crow Agent & Skill Review Agent** for an independent review, and include a rubber-duck review before release. The reusable version classification and user-decision rules are defined in the [Crow versioning policy](.apm/skills/crow-release/modules/versioning.md).

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
apm install bcgov/crow#v0.6.0 --global --target copilot
```

### On macOS / Linux

Install APM if it is not already available:

```bash
curl -sSL https://aka.ms/apm-unix | sh
```

Install Crow globally:

```bash
apm install bcgov/crow#v0.6.0 --global --target copilot
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
build/bcgov-crow-0.6.0.zip
```

The archive contains a standard `plugin.json`, so it can be installed through APM or used as a Copilot CLI plugin bundle. Consumers can install it globally with APM:

```powershell
apm install .\build\bcgov-crow-0.6.0.zip --global --target copilot
```

For Copilot CLI, unpack and install the plugin directory:

```powershell
Expand-Archive .\build\bcgov-crow-0.6.0.zip -DestinationPath .\build\copilot
copilot plugin install .\build\copilot\bcgov-crow-0.6.0
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