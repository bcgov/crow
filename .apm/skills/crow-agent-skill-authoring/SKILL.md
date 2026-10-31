---
name: crow-agent-skill-authoring
description: Create or update agents and skills in Crow or another repository with repository-appropriate naming, context-efficient routing, and deterministic validation.
---

# Crow Agent and Skill Authoring

Use this skill when adding or changing agents, skills, modules, templates, or their supporting scripts in a target repository, including when Crow is installed globally.

## Context-efficient loading

1. Read [`modules/design-pattern.md`](modules/design-pattern.md) for every change.
2. For changes in the Crow repository, read the canonical [`../crow-release/modules/versioning.md`](../crow-release/modules/versioning.md) policy. For another repository, follow its own versioning and packaging rules.
3. Read [`modules/public-release.md`](modules/public-release.md) when changing Crow's distributable content, examples, research, dependencies, tools, or packaging.
4. Read only the related existing agent, skill router, and modules. Do not load unrelated Crow capabilities.
5. Use the templates in [`resources/`](resources/) as starting structures, not as content to copy blindly.
6. Load [`modules/collection-management.md`](modules/collection-management.md) when a Crow collection, package subset, or distribution manifest changes.
7. Load [`modules/interaction-contracts.md`](modules/interaction-contracts.md) when an agent interviews users, writes or updates documents, reports completion, hands work to another agent, reads a live provider, or resumes prior work.

## Authoring loop

1. Identify the target repository from its repository metadata, not from the globally installed Crow skill's location or the directory name alone. If its identity is unclear, ask before choosing a naming convention. Inspect its existing agents and skills and whether an existing skill already owns the capability.
2. When creating an agent or skill in `bcgov/crow`, use the `crow-` prefix. In any other repository, ask the user which prefix to use **before creating the asset**. Inspect agent filenames and skill directory/frontmatter names for an established shared prefix; suggest it, or the repository name in lowercase kebab-case with a trailing hyphen if none exists. If existing prefixes conflict, present the candidates rather than selecting one silently. Apply the confirmed prefix to new asset identifiers and filenames following the target repository's conventions; do not impose `crow-` because Crow is installed globally.
3. Define a narrow trigger, in-scope behavior, non-goals, required tools, failure behavior, and a `## Completion gate` section that the validator requires for every agent.
4. Put orchestration in the agent, routing in `SKILL.md`, reusable knowledge in modules, stable output shapes in templates, and mechanical operations in scripts.
5. Keep the agent and router concise. Link to one canonical policy instead of repeating it.
6. Apply the [minimal-change decision ladder](../crow-application-architecture/modules/minimal-change.md) before creating a new asset, abstraction, dependency, or output contract. Preserve security, accessibility, correctness, and release gates when simplifying.
7. Store research and review evidence only in a repository-root ignored `evidence/` path outside `.apm/`, or in session-local storage. Never package or commit it.
8. In Crow, update `apm.yml`, `.github/plugin/plugin.json`, collection manifests when relevant, and README discovery lists when capabilities change. In another repository, update its own discovery and packaging surfaces.
9. Classify version impact and apply user-decision gates from the target repository's versioning policy, using Crow's canonical policy only for Crow changes.
10. In Crow, run [`scripts/Test-CrowAssets.ps1`](scripts/Test-CrowAssets.ps1), which
   checks local Markdown links and collection dependency closure, then the
   repository's package checks. Run
   [`scripts/Test-CrowAssetDependencyGraph.Tests.ps1`](scripts/Test-CrowAssetDependencyGraph.Tests.ps1)
   when changing graph validation, and
   [`scripts/Test-CrowSecurityRemediationScopes.Tests.ps1`](scripts/Test-CrowSecurityRemediationScopes.Tests.ps1)
   when changing the security-remediation scope routes. In another repository, run its relevant validation and package checks instead.
11. In Crow, run the dedicated Crow review and a rubber-duck review. Resolve material findings before completion.

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
- In Crow, collection manifests are version-aligned, resolve only repository-local source assets, and remain subsets of the full package.
- In Crow, the asset dependency graph finds no dead links; each collection includes the
  linked skills and modules required by its bundled agents.
- Local references resolve.
- No tracked evidence or sensitive material exists.
- Validator and package checks pass.
- Semantic version impact is recorded where the target repository requires it.
- In Crow, specialist and rubber-duck reviews are complete.
