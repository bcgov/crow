---
name: crow-high-availability
description: Assess and design business-hours release and runtime/framework/dependency update continuity for .NET, Java, and PHP. Defines evidence-backed operation criteria and specialist handoffs, not implementation, deployment, DR, or host/OS/database-engine patching.
---

# Application Maintenance Continuity

Use for a maintenance-continuity assessment or design, not ordinary package
updates, general architecture, pipeline authoring, performance engineering,
or an unsupported zero-downtime guarantee.

## Context-efficient loading

1. Load [`modules/assessment.md`](modules/assessment.md) for every assessment.
   Read existing `crow.config` references through
   [`crow-project-context`](../crow-project-context/SKILL.md) only when needed;
   do not update it.
2. For target design and maintenance runbooks, load
   [`modules/continuity-design.md`](modules/continuity-design.md) and
   [`modules/deployment-and-recovery.md`](modules/deployment-and-recovery.md).
3. Load only affected technology modules:
   [`dotnet.md`](modules/dotnet.md) for .NET project/runtime evidence,
   [`java.md`](modules/java.md) for verified Java Maven/Gradle/source evidence,
   [`php.md`](modules/php.md) for verified PHP/Composer evidence.
4. Route independently by actual hosting controls:
   - host services, IIS/application servers, plain containers and proxies:
     [`hosts-and-processes.md`](modules/hosting/hosts-and-processes.md);
   - an observed orchestrator:
     [`orchestrated-containers.md`](modules/hosting/orchestrated-containers.md);
   - managed slots/revisions/serverless/vendor controls:
     [`managed-platforms.md`](modules/hosting/managed-platforms.md).
   Load multiple routes only for affected components; unknown hosting is a
   missing input, not a Kubernetes default.
5. Load [`modules/verification-and-handoffs.md`](modules/verification-and-handoffs.md)
   when specifying criteria, judging supplied results, or preparing/consuming
   a handoff. Use the
   [report template](templates/high-availability-template.md) and, only when
   requested, the [handoff template](templates/availability-handoff-template.json).

## Workflow

Discover and classify evidence, confirm objectives, assess continuity gaps,
compare feasible patterns, then draft a phased design and runbooks. Follow
the [interaction contracts](../crow-agent-skill-authoring/modules/interaction-contracts.md)
for approvals, preservation, resumption, confidence, and completion.

The single-application default is `docs/high-availability.md`. For a monorepo,
follow the existing architecture service inventory and use
`docs/<service>/high-availability.md`, with handoffs beside it. Resolve ambiguous
services before writing. A shared ingress is a named dependency in each
affected assessment; a separate platform-scoped report needs explicit scope
and an agreed path, not an automatic new output.

Keep the structured continuity contract in one JSON fence in report Section 2,
between the template's markers. It is the canonical source for IDs, numeric
criteria, and result records; narrative sections reference IDs rather than
maintaining a second threshold matrix.

## Deterministic validation

Resolve the [validator](scripts/Test-HighAvailabilityOutput.ps1) relative to
this installed skill, not the consuming repository. PowerShell 5.1 and 7+
are supported. The script reads files/Git only; exits 0 valid, 1 invalid,
2 missing input. Run it before writing with `-Phase PreWrite`, and afterward
with `-Phase Report` (default):

```powershell
& <installed-skill>\scripts\Test-HighAvailabilityOutput.ps1 -RepoRoot <repository> -Path docs\high-availability.md -Phase PreWrite
& <installed-skill>\scripts\Test-HighAvailabilityOutput.ps1 -RepoRoot <repository> -Path docs\high-availability.md
```

For a handoff use `-Phase Handoff -Path <relative-handoff.json>`. Consumers
also pass `-RequireSignedOff -ExpectedConsumer <consumer-id>`. An explicitly
accepted revision difference requires `-AcceptRevisionMismatch`; record the
user's acceptance in the report first. `-AsOf <UTC-date>` makes expiry checks
repeatable. Never override a failed path, schema, result, or sign-off check.

## Completion gate

Validate structure and references, review the adequacy of objectives,
evidence, and proposed controls, and distinguish design approval from
operational demonstration. A passing validator does not prove continuity or
authorize implementation, live access, deployment, or traffic execution.
