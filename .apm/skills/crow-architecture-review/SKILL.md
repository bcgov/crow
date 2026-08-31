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

Do not load monorepo or update guidance when the observable repository state does not require it.

## Output and validation

Write completed documents only to the paths selected by the classification module. Do not modify bundled templates.

Before writing, validate the selected paths:

```powershell
& .\.apm\skills\crow-architecture-review\scripts\Test-ArchitectureOutput.ps1 -RepoRoot <repository-root> -Classification SingleApp -Phase PreWrite
```

After writing, rerun with `-Phase PostWrite`. For a monorepo, pass `-Classification Monorepo -ServiceInventoryPath <inventory.json>` in both phases. The inventory format and output contract are defined in the classification module. Treat a non-zero exit code as a failed architecture review.
