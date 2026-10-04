# Crow vision and capability governance

## Vision

Crow helps B.C. public-sector teams understand, improve, secure, and maintain
software. It makes agent-assisted delivery more reliable in both existing and new applications: people can trace a recommendation to evidence, make informed
decisions, and verify the outcome. Its guidance should be portable to other teams
where the underlying practices apply, without pretending that B.C.-specific policy
or services are universal.

## Principles

1. **Solve a repeatable problem.** Support discovery, design,
   implementation, deployment, testing, review, remediation, or maintenance. State the
   user and verifiable outcome. Setup and release support must enable these
   workflows.
2. **Ground advice in evidence.** Inspect relevant sources and distinguish facts from assumptions. Never invent organizational rules or approvals.
3. **Keep people in control.** Make external writes and consequential changes
   confirmation-gated. Expose failures and uncertainty; never report an
   unperformed check as passed.
4. **Treat quality as a gate.** Address security, privacy, accessibility,
   maintainability, and verification where relevant. Do not ship unmanageable
   risks or unverifiable outcomes.
5. **Be B.C.-first and portable.** Clearly identify and route B.C.-specific
   guidance. Cite public sources; state dependencies instead of embedding
   private infrastructure.
6. **Reuse and maintain before adding.** Extend an existing capability where
   possible. Agents orchestrate distinct roles and decisions; skills route
   reusable guidance; scripts perform deterministic checks. Keep triggers
   narrow. See the
   [design pattern](.apm/skills/crow-agent-skill-authoring/modules/design-pattern.md).
7. **Publish responsibly.** Exclude secrets, customer data, private
   operational details, and unlicensed content. Use synthetic examples. Follow
   [public release hygiene](.apm/skills/crow-agent-skill-authoring/modules/public-release.md).
8. **Protect the agent's context.** Keep entry points discoverable and
   narrowly triggered; load only relevant guidance. Prefer a small coherent
   collection over duplicative agents, large unconditional context, or
   novelty-driven features. Revisit and retire guidance that becomes stale.

## Admission decision

For each proposed agent or skill, record in its pull request:

- **Need:** What repeatable delivery task and verifiable outcome does it serve?
- **Fit:** Why can an existing asset not cover it, and why is it reusable
  beyond one project's private workflow?
- **Trust:** What evidence, permissions, human approvals, and quality checks
  does it require? How does it fail safely?
- **Support:** Who maintains its sources, dependencies, and validation?

Admit only when all four questions have satisfactory answers and the trust
and public-release gates above pass. Otherwise defer. Extend an existing
asset when it owns the need; add a distinct asset only for a distinct,
supportable outcome; keep private or one-off workflows project-local. General
productivity personas, unrelated business automation, duplicated guidance,
and unreviewed authority over production systems do not belong in Crow.

Maintainers record the decision in the pull request. Revisit changed sources,
dependencies, or scope; retire capabilities whose promises cannot be kept.
Accepted changes follow the
[authoring workflow](.apm/skills/crow-agent-skill-authoring/SKILL.md) and
[release policy](.apm/skills/crow-release/SKILL.md).
