# Crow Security Remediation

The Security Remediation collection provides a focused workflow for scanning
an application, documenting evidence-backed findings, and implementing and
verifying remediations.

Install it with the Crow release tag:

```powershell
apm install bcgov/crow/collections/security-remediation#v0.10.1 --global --target copilot
```

Invoke the [Crow Raven Setup Agent](../../.apm/agents/crow-raven-setup.agent.md)
first. The security review workflow requires code intelligence and may
require the Sonar MCP server, depending on the requested scan and configured
project connections.

## Included agents

- [Crow Raven Setup Agent](../../.apm/agents/crow-raven-setup.agent.md)
- [Crow Security & Dependency Review Agent](../../.apm/agents/crow-security-review.agent.md)
- [Crow Security Remediation Agent](../../.apm/agents/crow-security-remediation.agent.md)

## Included skills

- [crow-raven-setup](../../.apm/skills/crow-raven-setup/SKILL.md)
- [crow-project-context](../../.apm/skills/crow-project-context/SKILL.md)
- [crow-security-review](../../.apm/skills/crow-security-review/SKILL.md)
- [crow-sonar-scan](../../.apm/skills/crow-sonar-scan/README.md)
- [crow-application-architecture](../../.apm/skills/crow-application-architecture/SKILL.md)
- [crow-application-development](../../.apm/skills/crow-application-development/SKILL.md)
- [crow-testing](../../.apm/skills/crow-testing/SKILL.md)

The collection keeps external issue publication and ticket updates
confirmation-gated. Review findings and remediation scope before allowing any
write to GHAS, a work tracker, or another provider.
