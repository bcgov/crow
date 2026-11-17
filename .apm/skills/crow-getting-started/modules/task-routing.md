# Task-to-capability routes

This is a small intent map, not a parallel asset catalogue or execution
policy. Read the relevant rows and verify the chosen installed asset's
description and boundaries. Link to its owning guidance instead of copying
its procedure. Do not load every linked skill.

| Desired outcome | Starting route | Important distinction |
| --- | --- | --- |
| Understand an existing application's architecture | [Crow Architecture Review Agent](../../../agents/crow-architecture-review.agent.md) | Documents implemented behavior, not a new solution design. |
| Design a solution or choose application boundaries | [Crow Solution Architecture Agent](../../../agents/crow-solution-architecture.agent.md); [crow-application-architecture](../../crow-application-architecture/SKILL.md) where applicable | Design approval is not implementation approval. |
| Document or change schema, storage, ORM mappings, or migrations | [Crow Data Architecture Agent](../../../agents/crow-data-architecture.agent.md) | Coordinate affected consumers and owner approvals; do not deploy a migration implicitly. |
| Design analytics, a dimensional warehouse, or reporting requirements | [Crow Analytics Design Agent](../../../agents/crow-analytics-design.agent.md) | Design and signed-off handoff, not warehouse implementation. |
| Extract enforced business rules | [Crow Business Rule Documentation Agent](../../../agents/crow-business-rule-documentation.agent.md) | Source evidence and supplied guides must be reconciled. |
| Plan or add unit/integration tests and manual QA coverage | [Crow Testing Agent](../../../agents/crow-testing.agent.md) | Browser E2E automation and general production fixes are outside its scope. |
| Review application security and dependencies, with applicable scans | [Crow Security & Dependency Review Agent](../../../agents/crow-security-review.agent.md) | A scan alone is not the complete security review; required providers and targets must be available and authorized. |
| Fix verified security findings or configured security tickets | [Crow Security Remediation Agent](../../../agents/crow-security-remediation.agent.md) | Requires the applicable current findings and architecture inputs; verify findings before edits. |
| Update a runtime, framework, or dependencies routinely | [Crow Framework & Dependency Update Agent](../../../agents/crow-framework-dependency-update.agent.md) | Routine maintenance does not require a security-review report. |
| Assess/design business-hours application release or update continuity | [Crow High Availability Design Agent](../../../agents/crow-high-availability.agent.md) | Assessment/design only; measurable critical-operation criteria, no implementation/deployment or host/OS/database-engine patching. Not DR or a prerequisite for routine/urgent updates. |
| Review a diff or hosted change | [Crow Code Review Agent](../../../agents/crow-code-review.agent.md) | Read-only feedback, not automatic correction or posted comments. |
| Review unnecessary complexity | [Crow Simplification Review Agent](../../../agents/crow-simplification-review.agent.md) | Opt-in simplification review, not a substitute for security or correctness review. |
| Build or evolve a feature/API | The client's normal coding agent using [crow-application-development](../../crow-application-development/SKILL.md) | There is no separate Crow application-implementation agent to invent. Add architecture/testing guidance only when applicable. |
| Assess or author application CI | [Crow CI Pipeline Agent](../../../agents/crow-ci-pipelines.agent.md) | Follow the supported platform, language, and existing test boundaries. |
| Design, review, or fix accessible B.C. government interfaces | [Crow B.C. Government UX Agent](../../../agents/crow-bcgov-ux.agent.md) | Preserve agreed UX scope; this is not user-journey design. |
| Replace legacy technology without changing external contracts or its datastore | [Crow Legacy Modernization Agent](../../../agents/crow-legacy-modernization.agent.md) | An engine/schema/contract redesign cannot be silently included in this preservation workflow. |
| Re-platform with separately approved data, API, or UX changes; coordinate several domains | A coordinator in the client's normal agent session, using [multi-agent.md](multi-agent.md) | Use existing specialist owners; separately scope changes outside the legacy-modernization contract. |
| Summarize architecture and security reports for executives | [Crow Executive Summary Report Agent](../../../agents/crow-executive-report.agent.md) | Required source reports must exist; summaries are not new security evidence. |
| Set up or maintain Raven and code intelligence | [Crow Raven Setup Agent](../../../agents/crow-raven-setup.agent.md) | Installations and configuration changes remain separately approved. |
| Author or review Crow customizations | [Crow Agent & Skill Authoring Agent](../../../agents/crow-agent-skill-authoring.agent.md) or [Crow Agent & Skill Review Agent](../../../agents/crow-agent-skill-review.agent.md) | Choose authoring versus read-only review. |
| Prepare a Crow release | [crow-release](../../crow-release/SKILL.md) | Maintainer workflow with explicit publication and version gates. |

Read [crow-project-context](../../crow-project-context/SKILL.md) only when
existing `crow.config` references are needed. Do not create or update it
during onboarding. If no route fits, name the gap and offer the client's
normal agent with verified relevant skills; do not force a misleading match.
