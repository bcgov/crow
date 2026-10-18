---
name: crow-legacy-modernization
description: Coordinate a legacy application or service replacement through process and contract inventory, business rules, portable baseline tests, supported target architecture, approved implementation, and old/new equivalence. Use for end-to-end modernization, not a routine framework upgrade or isolated API test.
---

# Legacy Modernization

Use with the Crow Legacy Modernization Agent for an end-to-end replacement.
The agent owns orchestration and stop decisions. This skill supplies
modernization-specific acceptance gates; the existing skills retain their
domain-specific workflows and output authority.

## Routing

1. Load [`modules/phase-gates.md`](modules/phase-gates.md) for every run and
   use [`resources/modernization-plan-template.md`](resources/modernization-plan-template.md)
   to create or update `docs/modernization/plan.md` in the scoped application's
   owning repository. For applications in separate repositories, select the
   target repository root for each routed skill: its reports and testing
   artifacts stay in that repository's own `docs/` folder. Link evidence
   across repositories with revision-qualified, safe references rather than
   writing reports into a different repository. If multiple applications
   share one repository, use service-specific paths only where the owning
   skill supports them; stop before fixed-path business-rules or
   solution-architecture outputs would overwrite another application's
   reports. Agree on a separate repository scope or supported output paths
   before proceeding.
   Load [`crow-project-context`](../crow-project-context/SKILL.md) when
   `crow.config` exists.
2. Load [`crow-architecture-review`](../crow-architecture-review/SKILL.md)
   to document the implemented architecture. For REST/SOAP, validate its
   operation/response-case inventory before scenario design. Load
   [`crow-business-rules`](../crow-business-rules/SKILL.md) to document
   enforced rules; also inventory process triggers, transitions, actors,
   external effects, and failure paths in the modernization plan. Neither
   an architecture report nor a rules report alone is a process inventory.
3. Load [`crow-testing`](../crow-testing/SKILL.md) for scenario approval,
   baseline characterization, implementation-independent tests, and manual
   coverage. Route to its `characterization-tests.md`,
   `migration-testing.md`, and, for REST/SOAP, `api-modernization-harness.md`
   references as directed by that skill. Reuse its HTTP inventory coverage
   gate; it does not establish coverage for non-HTTP interfaces or UI.
   Respect its manual-coverage module's review status, feature ownership, and
   rule that QA execution history stays outside the repository.
4. Load [`crow-solution-architecture`](../crow-solution-architecture/SKILL.md)
   for the proposed solution and stakeholder decisions. Use
   [`crow-framework-updates`](../crow-framework-updates/SKILL.md) for
   vendor-backed support and migration evidence, **not** permission to
   upgrade the legacy app in place. Load
   [`crow-application-architecture`](../crow-application-architecture/SKILL.md)
   for affected application boundaries and technology choices.
5. After approval, load
   [`crow-application-development`](../crow-application-development/SKILL.md)
   to implement slices and [`crow-code-review`](../crow-code-review/SKILL.md)
   for its post-change review. Consult
   [`crow-bcgov-ux`](../crow-bcgov-ux/SKILL.md) read-only when proposing
   user-visible changes, and apply it during implementation only after
   approval; UX advice does not authorize an interface change.
   Apply the security modules routed by application development. A security
   conflict that would require a changed external contract blocks this
   replacement rather than silently changing it.

## Boundaries

Do not author a second business-rules report, scenario catalogue, manual-QA
index, architecture document, or test harness under this skill. The plan is
only the cross-workflow process/contract inventory, traceability, approvals,
and handoff. Use existing repository-native tests and documentation.
Browser E2E automation is outside `crow-testing`'s scope; use appropriate
unit/integration checks and human-run manual scenarios rather than claiming
UI equivalence from API tests.

If the target, approval, tool, build, test environment, or evidence required
for a phase is unavailable, mark the phase blocked, explain the limitation,
and stop before dependent implementation or equivalence claims. An
unattended run must never infer an approval.
