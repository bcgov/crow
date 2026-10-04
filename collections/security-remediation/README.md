# Crow Security Remediation

The Security Remediation collection provides a focused workflow for scanning
an application, documenting its security-relevant architecture, producing
evidence-backed findings, and implementing and verifying remediations.

Install it from Crow's release-maintained stable branch:

```powershell
apm install bcgov/crow/collections/security-remediation#stable --global --target copilot
```

For an immutable install of this release:

```powershell
apm install bcgov/crow/collections/security-remediation#v0.11.4 --global --target copilot
```

Invoke the [Crow Raven Setup Agent](../../.apm/agents/crow-raven-setup.agent.md)
first. The security review workflow requires code intelligence and may
require the Sonar MCP server, depending on the requested scan and configured
project connections.

## Included agents

- [Crow Raven Setup Agent](../../.apm/agents/crow-raven-setup.agent.md)
- [Crow Architecture Review Agent](../../.apm/agents/crow-architecture-review.agent.md)
- [Crow Security & Dependency Review Agent](../../.apm/agents/crow-security-review.agent.md)
- [Crow Security Remediation Agent](../../.apm/agents/crow-security-remediation.agent.md)

## Included skills

- [crow-raven-setup](../../.apm/skills/crow-raven-setup/SKILL.md)
- [crow-project-context](../../.apm/skills/crow-project-context/SKILL.md)
- [crow-architecture-review](../../.apm/skills/crow-architecture-review/SKILL.md)
- [crow-security-review](../../.apm/skills/crow-security-review/SKILL.md)
- [crow-sonar-scan](../../.apm/skills/crow-sonar-scan/README.md)
- [crow-application-architecture](../../.apm/skills/crow-application-architecture/SKILL.md)
- [crow-application-development](../../.apm/skills/crow-application-development/SKILL.md)
- [crow-testing](../../.apm/skills/crow-testing/SKILL.md)

The collection keeps external issue publication and ticket updates
confirmation-gated. Review findings and remediation scope before allowing any
write to GHAS, a work tracker, or another provider.

Run the Architecture Review Agent first when architecture documentation is
missing or stale. It produces a compact validated
`architecture-security-facts.json` handoff that lets the security review reuse
verified boundaries and workflows without loading the full architecture
document. The security review still works without the handoff and re-verifies
stale or inferred facts.
