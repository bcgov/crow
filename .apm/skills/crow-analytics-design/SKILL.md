---
name: crow-analytics-design
description: Guide analytics requirements interviews, local-first source analysis, dimensional design, and signed-off handoffs without implementing or deploying a warehouse or report.
---

# Crow Analytics Design

Use this skill for analytics or report requirements, dimensional warehouse
design, source mapping, grain decisions, and design handoffs. It does not
build database schemas, transformations, semantic models, or reports.

## Context-efficient loading

1. Load [`modules/interview.md`](modules/interview.md) for requirements and
   sign-off.
2. Load [`modules/source-analysis.md`](modules/source-analysis.md) when
   examining source schemas, CSVs, extracts, or user-supplied source notes.
3. Load [`modules/handoff.md`](modules/handoff.md) when preparing or reviewing
   a design handoff.
4. Load [`modules/references.md`](modules/references.md) for source links and
   use only references relevant to the selected technologies.
5. For physical relational model changes, offer the
   [`crow-data-architecture`](../crow-data-architecture/SKILL.md) capability
   only as an explicit user-selected handoff.

## Workflow

1. Inspect available local evidence and supplied documentation before
   interviewing.
2. Run the focused interview, track unanswered items, and separate observed
   facts from inferred proposals.
3. Draft only the artifacts requested by the user. Ask permission before
   creating or updating project files.
4. Obtain explicit design sign-off before a signed-off handoff.
5. Report outputs, evidence, assumptions, conflicts, failed checks, and
   deferred capabilities.

## Completion gate

Do not report a design as signed off until its requirements, candidate grain,
bus matrix, glossary, entity map, security assumptions, and acceptance
criteria have been reviewed by the user. A plan or handoff is never reported
as an executed build.
