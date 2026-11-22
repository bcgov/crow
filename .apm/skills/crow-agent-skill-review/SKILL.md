---
name: crow-agent-skill-review
description: Review Crow agents and skills for correctness, context and token efficiency, automation opportunities, knowledge/execution separation, semantic versioning, and public-release suitability.
---

# Crow Agent and Skill Review

Use this skill for a read-only review of proposed or existing Crow agents, skills, modules, templates, scripts, and package metadata.

## Review sequence

1. Determine the bounded diff or asset set and all connected discovery surfaces.
2. For changes in Crow, resolve and read `GOVERNANCE.md` from the target
   repository root identified from repository metadata, not relative to the
   installed Crow package. If that target file is absent, use the
   [public governance file](https://github.com/bcgov/crow/blob/main/GOVERNANCE.md).
   Assess applicable principles and review PR-ready Need/Fit/Trust/Support
   admission answers for each new or materially changed agent or skill. If a
   pull request exists, verify the record is included there; otherwise, treat
   it as a draft that must be carried into the pull request before merge.
3. Run `../crow-agent-skill-authoring/scripts/Test-CrowAssets.ps1`.
4. Read the canonical [`../crow-release/modules/versioning.md`](../crow-release/modules/versioning.md) policy.
5. Apply [`modules/review-rubric.md`](modules/review-rubric.md).
6. Verify every finding against the current source and report exact paths.
7. Ask an available rubber-duck reviewer to challenge the preliminary review. Verify its suggestions before adopting them.
8. Classify the change and apply user-decision gates from the canonical versioning policy.

## Severity

- **Blocking:** invalid package, unsafe public content, secret exposure, broken references, or an unconfirmed major-version decision.
- **High:** incomplete workflow, unsafe tool authority, silent failure, misleading trigger, or packaged evidence.
- **Medium:** avoidable context bloat, duplicated policy, missing deterministic check, or weak knowledge/execution separation.
- **Low:** maintainability improvement with no current behavioral impact.

## Output format

Use [`review-template.md`](review-template.md). Findings come first. Do not create a report file unless the user asks; return the review in the conversation by default.
