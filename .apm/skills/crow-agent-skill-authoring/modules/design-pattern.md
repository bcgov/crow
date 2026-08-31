# Agent and Skill Design Pattern

## Responsibility boundaries

| Asset | Owns | Avoid |
|---|---|---|
| Agent | role, tool orchestration, decisions, failure behavior, completion gate | large reference catalogues, duplicated framework knowledge |
| `SKILL.md` | invocation trigger, routing, concise workflow | loading every module unconditionally |
| Module | reusable domain knowledge and acceptance criteria | tool-specific orchestration that belongs to one agent |
| Template | stable document or configuration shape | embedded workflow policy |
| Script | deterministic checks and transformations with explicit failures | judgment calls, hidden defaults, silent recovery |
| Evidence | temporary research, measurements, transcripts, source extracts | tracked or packaged content |

An agent may consume multiple skills. A skill may support multiple agents. Keep knowledge independent of a particular agent when another capability could reuse it.

## Progressive disclosure

Use a small router that selects modules from observable context. Load a module only when the task, language, framework, output, or risk surface requires it.

Prefer:

```text
SKILL.md
  -> modules/foundation.md
  -> modules/dotnet.md only for .NET
  -> modules/persistence.md only for data access
```

Avoid a single router that embeds every framework, example, and edge case. Avoid agents that repeat module contents.

## Context review

Review both size and utility:

- remove repeated principles, examples, and completion criteria;
- replace prose inventories with direct links or generated listings;
- make large optional references into modules;
- use frontmatter descriptions that are specific enough to prevent accidental loading;
- keep one canonical source for version policy, security rules, and public-release rules;
- ensure the model reads generated assets only when human judgment is needed.

Size warnings from the validator are prompts for review, not automatic proof of poor design. Large files must justify why their content cannot be routed or generated.

## Failure behavior

State what must stop the workflow: missing source files, ambiguous scope, unavailable required tools, invalid manifests, failed checks, or unconfirmed major-version changes. Do not convert a failed check into a success-shaped result.

## Deterministic opportunities

Prefer scripts for:

- enumerating agents and skills;
- checking frontmatter names and required fields;
- synchronizing versions and README examples;
- validating local Markdown references;
- identifying tracked evidence;
- measuring context size;
- packaging archives and calculating checksums;
- calling release APIs or CLIs with explicit parameters.

Scripts must validate prerequisites, use non-zero exit codes for failures, and avoid broad cleanup or unrelated file changes.
