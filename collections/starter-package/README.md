# Crow Starter Package

The Starter Package is the focused Crow installation for daily brownfield
development. It includes the agents and skills needed to understand an
existing application, make aligned changes, build accessible interfaces, and
verify the result with automated tests.

Install it with the Crow release tag:

```powershell
apm install bcgov/crow/collections/starter-package#v0.10.3 --global --target copilot
```

Invoke the [Crow Raven Setup Agent](../../.apm/agents/crow-raven-setup.agent.md)
first. It configures the optional Raven servers and
[codebase-memory-mcp](https://github.com/bcgov/codebase-memory-mcp) used by
the architecture and testing workflows.

## Included agents

- [Crow Raven Setup Agent](../../.apm/agents/crow-raven-setup.agent.md)
- [Crow Architecture Review Agent](../../.apm/agents/crow-architecture-review.agent.md)
- [Crow B.C. Government UX Agent](../../.apm/agents/crow-bcgov-ux.agent.md)
- [Crow Testing Agent](../../.apm/agents/crow-testing.agent.md)

## Included skills

- [crow-raven-setup](../../.apm/skills/crow-raven-setup/SKILL.md)
- [crow-project-context](../../.apm/skills/crow-project-context/SKILL.md)
- [crow-security-review](../../.apm/skills/crow-security-review/SKILL.md)
- [crow-architecture-review](../../.apm/skills/crow-architecture-review/SKILL.md)
- [crow-application-architecture](../../.apm/skills/crow-application-architecture/SKILL.md)
- [crow-application-development](../../.apm/skills/crow-application-development/SKILL.md)
- [crow-bcgov-ux](../../.apm/skills/crow-bcgov-ux/SKILL.md)
- [crow-testing](../../.apm/skills/crow-testing/SKILL.md)
