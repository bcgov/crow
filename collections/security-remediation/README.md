# Crow Security Remediation

The Security Remediation collection provides a focused workflow for scanning
an application, documenting its security-relevant architecture, producing
evidence-backed findings, and implementing and verifying remediations.
Routine framework and dependency maintenance has a separate
[Crow Framework & Dependency Update Agent](../../.apm/agents/crow-framework-dependency-update.agent.md)
in the Starter Package.
The existing `framework-upgrades` and `dependencies` scopes remain as
deprecated compatibility routes through the update skills.

Install it from Crow's release-maintained stable branch:

```powershell
apm install bcgov/crow/collections/security-remediation#stable --global --target copilot
```

For an immutable install of this release:

```powershell
apm install bcgov/crow/collections/security-remediation#v0.12.3 --global --target copilot
```

Invoke the [Crow Raven Setup Agent](../../.apm/agents/crow-raven-setup.agent.md)
first. The security review workflow requires code intelligence and may
require the Sonar MCP server, depending on the requested scan and configured
project connections. When Sonar MCP is configured or selected during setup,
the Raven Setup Agent also verifies the local SonarScanner CLI and, when a
compatible SDK is available, the .NET/MSBuild scanner; it offers compatible
updates only after confirmation.

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
- [crow-framework-updates](../../.apm/skills/crow-framework-updates/SKILL.md)
- [crow-dependency-updates](../../.apm/skills/crow-dependency-updates/SKILL.md)

The collection also includes the
[technology-preferences module](../../.apm/skills/crow-solution-architecture/modules/technology-preferences.md)
and its [command-line helper](../../.apm/skills/crow-solution-architecture/scripts/technology-preferences.mjs),
conditionally used by `crow-project-context`.

The collection also includes the
[BC Gov UX review-remediation module](../../.apm/skills/crow-bcgov-ux/modules/review-remediation.md),
conditionally referenced by `crow-testing`'s manual-coverage guidance.

The collection keeps external issue publication and ticket updates
confirmation-gated. Review findings and remediation scope before allowing any
write to GHAS, a work tracker, or another provider.

Run the Architecture Review Agent first when architecture documentation is
missing or stale. It produces a compact validated
`architecture-security-facts.json` handoff that lets the security review reuse
verified boundaries and workflows without loading the full architecture
document. The security review still works without the handoff and re-verifies
stale or inferred facts.
