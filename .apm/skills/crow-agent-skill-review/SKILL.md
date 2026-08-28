---
name: crow-agent-skill-review
description: Review Crow agents and skills for correctness, context and token efficiency, automation opportunities, knowledge/execution separation, semantic versioning, and public-release suitability.
---

# Crow Agent and Skill Review

Use this skill for a read-only review of proposed or existing Crow agents, skills, modules, templates, scripts, and package metadata.

## Review sequence

1. Determine the bounded diff or asset set and all connected discovery surfaces.
2. Run `../crow-agent-skill-authoring/scripts/Test-CrowAssets.ps1`.
3. Read the canonical [`../crow-release/modules/versioning.md`](../crow-release/modules/versioning.md) policy.
4. Apply [`modules/review-rubric.md`](modules/review-rubric.md).
5. Verify every finding against the current source and report exact paths.
6. Ask an available rubber-duck reviewer to challenge the preliminary review. Verify its suggestions before adopting them.
7. Classify the change and apply user-decision gates from the canonical versioning policy.

## Severity

- **Blocking:** invalid package, unsafe public content, secret exposure, broken references, or an unconfirmed major-version decision.
- **High:** incomplete workflow, unsafe tool authority, silent failure, misleading trigger, or packaged evidence.
- **Medium:** avoidable context bloat, duplicated policy, missing deterministic check, or weak knowledge/execution separation.
- **Low:** maintainability improvement with no current behavioral impact.

## Output format

Use [`review-template.md`](review-template.md). Findings come first. Do not create a report file unless the user asks; return the review in the conversation by default.
