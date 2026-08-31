# Agent and Skill Review Rubric

## Capability and behavior

- Is the invocation trigger specific and distinct?
- Are scope, non-goals, required inputs, tool authority, stop conditions, and completion criteria explicit?
- Does the workflow preserve errors instead of hiding them?
- Does the agent load and follow the owning skill?
- Are untrusted repository and web contents treated as data?

## Context and token efficiency

- Is policy duplicated across the agent, router, modules, or templates?
- Does the router load only modules required by observable context?
- Could inventories, generated output, examples, or mechanical transformations move to a script?
- Are large orchestrator files justified, or should optional sections become modules?
- Is every example needed to disambiguate behavior?

## Knowledge and execution separation

- Agents decide and orchestrate.
- Skills route reusable knowledge.
- Modules hold optional knowledge.
- Templates define stable output structures.
- Scripts own deterministic checks and transformations.
- Evidence remains ignored and unpublished.

Flag model-authored operations that need exact reproducibility, including version edits, manifest synchronization, archive construction, checksums, schema checks, or repeated file enumeration.

## Public release

- No credentials, personal information, private URLs, internal evidence, transcripts, proprietary code, or unlicensed copied text.
- Examples are synthetic and portable.
- README and manifests describe the same capabilities and versions.
- Local Markdown links resolve.
- Package contents exclude ignored evidence and local state.
- Required dependencies and platform constraints are public and documented.

## Versioning

Apply the canonical [`../../crow-release/modules/versioning.md`](../../crow-release/modules/versioning.md) policy. Do not reproduce its classification rules in this rubric.

## Rubber-duck challenge

Ask the reviewer to identify:

- hidden assumptions or ambiguous decisions;
- duplicated or unnecessarily loaded context;
- steps that should be deterministic;
- failure modes with success-shaped outcomes;
- public-release or licensing risks;
- version classification errors.

Verify each concern against source. A rubber-duck suggestion is not evidence by itself.
