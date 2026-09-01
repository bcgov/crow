---
name: crow-agent-skill-authoring
description: Create or update Crow agents and skills with consistent structure, progressive context loading, deterministic tooling, public-release hygiene, and semantic-version classification.
---

# Crow Agent and Skill Authoring

Use this skill when adding or changing Crow agents, skills, modules, templates, or their supporting scripts.

## Context-efficient loading

1. Read [`modules/design-pattern.md`](modules/design-pattern.md) for every change.
2. Read the canonical [`../crow-release/modules/versioning.md`](../crow-release/modules/versioning.md) policy for every change.
3. Read [`modules/public-release.md`](modules/public-release.md) when content, examples, research, dependencies, tools, or packaging change.
4. Read only the related existing agent, skill router, and modules. Do not load unrelated Crow capabilities.
5. Use the templates in [`resources/`](resources/) as starting structures, not as content to copy blindly.

## Authoring loop

1. Identify the capability boundary and whether an existing skill already owns it.
2. Define a narrow trigger, in-scope behavior, non-goals, required tools, failure behavior, and completion gate.
3. Put orchestration in the agent, routing in `SKILL.md`, reusable knowledge in modules, stable output shapes in templates, and mechanical operations in scripts.
4. Keep the agent and router concise. Link to one canonical policy instead of repeating it.
5. Store research and review evidence only in a repository-root ignored `evidence/` path outside `.apm/`, or in session-local storage. Never package or commit it.
6. Update `apm.yml`, `.github/plugin/plugin.json`, and README discovery lists when capabilities change.
7. Classify version impact and apply user-decision gates from the canonical versioning policy.
8. Run [`scripts/Test-CrowAssets.ps1`](scripts/Test-CrowAssets.ps1), then the repository's package checks.
9. Run the dedicated Crow review and a rubber-duck review. Resolve material findings before completion.

For cross-cutting platform or reuse guidance, prefer a conditionally routed
technology-neutral module over a new monolithic agent or skill. Preserve
contract owners, approval gates, freshness/evidence qualifiers, and existing
UX or testing boundaries.

## Deterministic-first rule

Use a script instead of model prose when the operation can be expressed as stable inputs, transformations, and exit codes. Good candidates include manifest synchronization, naming checks, link validation, context-size measurement, schema validation, packaging, checksums, and release creation. Keep judgment-heavy work such as capability boundaries and ambiguity resolution in the agent.

## Completion gate

- Agent and skill names and descriptions have clear invocation boundaries.
- Only relevant modules are loaded.
- Package manifests and documentation agree.
- Local references resolve.
- No tracked evidence or sensitive material exists.
- Validator and package checks pass.
- Semantic version impact is recorded.
- Specialist and rubber-duck reviews are complete.
