---
name: crow-architecture-review
description: Routes the Crow Architecture Review Agent through repository classification, evidence-based inspection, REST/SOAP operation inventory when applicable, architecture document generation or update, and deterministic output validation.
---

# Architecture Review

Use this skill with the Crow Architecture Review Agent when creating or updating architecture documentation.

## Context-efficient loading

1. Load [`../crow-project-context/SKILL.md`](../crow-project-context/SKILL.md) and read `crow.config` when the repository has one.
2. Always load [`modules/repository-classification.md`](modules/repository-classification.md).
3. After classification, load [`modules/repository-inspection.md`](modules/repository-inspection.md) and [`architecture-template.md`](architecture-template.md).
4. Load [`modules/security-handoff.md`](modules/security-handoff.md) and
   [`resources/security-handoff-template.json`](resources/security-handoff-template.json)
   when producing or updating architecture output.
5. Load [`modules/update-mode.md`](modules/update-mode.md) only when an architecture document already exists.
6. Load [`resources/architecture-index-template.md`](resources/architecture-index-template.md) only for a monorepo.
7. Load [`modules/api-inventory.md`](modules/api-inventory.md) and
   [`resources/api-inventory-template.json`](resources/api-inventory-template.json)
   when repository evidence shows a REST or SOAP API.
8. Load `../crow-application-architecture/modules/unicode-and-utf8.md` for the Unicode inspection pass.
9. Load `../crow-application-architecture/modules/platform-alignment.md` only when repository evidence shows a shared capability, canonical register, public service, integration adapter, or one-to-many dependency.
10. Load `../crow-application-architecture/modules/zero-trust.md` only when repository evidence shows a meaningful identity, device, resource, transaction, privileged, workload, network, API, external-decision, or cross-service trust boundary.
11. Load the applicable sections of `../crow-application-architecture/modules/service-responsibilities.md` when source or documentation indicates decisions affecting people, information stores or derived copies, or multiple service channels.

Do not load monorepo or update guidance when the observable repository state does not require it.

## Output and validation

Write completed documents only to the paths selected by the classification module. Do not modify bundled templates.

Before writing, resolve `scripts/Test-ArchitectureOutput.ps1` relative to this installed skill directory, not relative to the target repository. Pass the target repository separately:

```powershell
& <crow-architecture-review-skill-directory>\scripts\Test-ArchitectureOutput.ps1 -RepoRoot <repository-root> -Classification SingleApp -Phase PreWrite
```

After writing the Markdown and its `architecture-security-facts.json` sidecar,
rerun with `-Phase PostWrite -RequireSecurityHandoff`. When APIs were
identified, also write and validate the sibling `api-inventory.json`; pass
`-RequireApiInventory` for a single application. For a monorepo, mark each
API-bearing service with `apiInventoryRequired: true` in the service inventory
and pass
`-Classification Monorepo -ServiceInventoryPath <inventory.json>` in both
phases. The service inventory, security handoff, and API inventory formats are
defined in their routed modules. Treat a non-zero exit code as a failed
architecture review.

During the bounded architecture inspection, apply the routed platform-alignment
module conditionally. Preserve `Unknown` or `N/A` when role, reuse, ownership,
custodianship, or contract evidence is unavailable; absence of a shared
catalogue is not evidence that a new service is required.

During the bounded inspection, when Zero Trust is routed, record protected
resources and access paths, enforcement points, authorization separate from
authentication, least-privilege duration, revocation, degradation, exceptions,
telemetry, and evidence confidence. Do not infer enterprise-wide posture.

When service responsibilities are routed, distinguish implemented behavior
from proposed or unknown decision-review, information-lifecycle, and
cross-channel paths. Do not infer approvals or operational staffing from code.

Keep the handoff token-efficient: normalize source locations in its `evidence`
array, reference them by ID, and include only security-relevant facts,
workflows, and unknowns. The Markdown remains the complete human-facing
architecture record.
