---
name: crow-architecture-review
description: Routes the Crow Architecture Review Agent through repository classification, evidence-based inspection, architecture document generation or update, and deterministic output validation.
---

# Architecture Review

Use this skill with the Crow Architecture Review Agent when creating or updating architecture documentation.

## Context-efficient loading

1. Always load [`modules/repository-classification.md`](modules/repository-classification.md).
2. After classification, load [`modules/repository-inspection.md`](modules/repository-inspection.md) and [`architecture-template.md`](architecture-template.md).
3. Load [`modules/update-mode.md`](modules/update-mode.md) only when an architecture document already exists.
4. Load [`resources/architecture-index-template.md`](resources/architecture-index-template.md) only for a monorepo.
5. Load `../crow-application-architecture/modules/unicode-and-utf8.md` for the Unicode inspection pass.
6. Load `../crow-application-architecture/modules/platform-alignment.md` only when repository evidence shows a shared capability, canonical register, public service, integration adapter, or one-to-many dependency.
7. Load `../crow-application-architecture/modules/zero-trust.md` only when repository evidence shows a meaningful identity, resource, transaction, privileged, workload, network, API, external-decision, or cross-service trust boundary.

Do not load monorepo or update guidance when the observable repository state does not require it.

## Output and validation

Write completed documents only to the paths selected by the classification module. Do not modify bundled templates.

Before writing, resolve `scripts/Test-ArchitectureOutput.ps1` relative to this installed skill directory, not relative to the target repository. Pass the target repository separately:

```powershell
& <crow-architecture-review-skill-directory>\scripts\Test-ArchitectureOutput.ps1 -RepoRoot <repository-root> -Classification SingleApp -Phase PreWrite
```

After writing, rerun with `-Phase PostWrite`. For a monorepo, pass `-Classification Monorepo -ServiceInventoryPath <inventory.json>` in both phases. The inventory format and output contract are defined in the classification module. Treat a non-zero exit code as a failed architecture review.

During the bounded architecture inspection, apply the routed platform-alignment
module conditionally. Preserve `Unknown` or `N/A` when role, reuse, ownership,
custodianship, or contract evidence is unavailable; absence of a shared
catalogue is not evidence that a new service is required.

During the bounded inspection, when Zero Trust is routed, record protected
resources and access paths, enforcement points, authorization separate from
authentication, least-privilege duration, revocation, degradation, exceptions,
telemetry, and evidence confidence. Do not infer enterprise-wide posture.
