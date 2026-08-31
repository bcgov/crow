# Maintaining this skill as the ecosystem changes

**This file is for whoever edits this skill, not for testing engagements.** `SKILL.md` links it only from the
maintainer section and excludes it from runtime routing. It exists so that when C#/.NET (or a future stack
this skill grows to cover) gains a new version or feature, the right files can be found and updated quickly
instead of re-auditing the whole skill.

**Before editing any row's target, verify the current fact by checking an authoritative source (Microsoft
Learn, the relevant analyzer/package's own docs/changelog) — don't rely on recall.** Every version claim and
analyzer rule ID currently in this skill was confirmed by search at the time it was written, not from
memory; ecosystem facts age faster than this skill gets revisited, and doubly so for anything past a model's
training cutoff.

## Trigger table

| Ecosystem event | Files to check | What to verify/update |
|---|---|---|
| New C# language version ships | `modules/reference/language-features-for-testability.md` | The "what the project can use" section and the opportunity table — does the new version add a testability-relevant feature? Update or remove the "C# has no native discriminated unions" honesty note if that ever ships. |
| | `modules/reference/design-smell-catalog.md`, `modules/reference/design-smell-entries.md` | The "Code predating a language feature that would enforce the rule" triage row (catalog) and entry/examples (entries) — do they still name the newest relevant gap? |
| New .NET runtime release (new TFM) | `modules/reference/language-features-for-testability.md` § "what the project can use" | TFM-gating guidance and any per-feature "available from" claims that assumed the previous latest TFM. |
| | `modules/discovery.md` | The TFM-vs-idiom scan step (reads `.editorconfig`, `<Nullable>`, `<LangVersion>`, `<EnforceCodeStyleInBuild>`) — still the right set of project-level signals to check? |
| An analyzer (SonarQube, Roslyn, `CAxxxx`) starts covering something this skill currently lists as uncovered | `modules/reference/language-features-for-testability.md` | Move the row from the "opportunities" (analyzer-invisible) table to the "already covered" (cite, don't hunt) table. |
| | `modules/reference/design-smell-catalog.md` | Update the triage table's `Rule` column for the same item so it stops reading as a `—` (no tool covers it) row. |
| A BCL feature's availability or backport policy changes (e.g. `TimeProvider`'s netstandard/net4xx backport) | `modules/reference/language-features-for-testability.md` | Re-verify the "available from" column for that feature. |
| New major version of xUnit, CsCheck, Bogus/AutoBogus, or EF Core with **breaking** API changes | `modules/dotnet/unit-tests.md`, `modules/dotnet/integration-tests.md` | The "detect first, default second" stack-defaults section — still the right default, still the right API shape? |
| | `modules/reference/reusable-test-suites.md`, `modules/reference/test-data-builders.md`, `modules/reference/property-based-testing.md` | Any code shape/API usage tied to the library that changed. |
| | `modules/reference/integration/fixtures.md`, `seeding-and-ids.md` | EF Core-specific mechanics (`SET IDENTITY_INSERT` handling, connection-pooling behavior, cleanup patterns), if EF Core changed. |
| xUnit, CsCheck, Bogus/AutoBogus, or EF Core ships a **non-breaking feature release** (nothing broke; ask instead whether the new capability removes a workaround this skill currently teaches) | Same files as the breaking-change row above, scoped to whichever library changed | Does the new feature replace a hand-rolled pattern or documented gotcha with a built-in one — e.g. a bulk-delete API removing `cleanup-and-isolation.md`'s manual FK-ordered-delete workaround, a better CsCheck shrinking/reporting mode, a Bogus/AutoBogus generator primitive replacing a hand-rolled one in `test-data-builders.md`? Only worth updating if it **simplifies** what's taught (fewer lines, fewer moving parts, removes a documented gotcha) — same "must remove more than it adds" bar `testability-improvements.md` applies to a target project's code, applied here to this skill's own content. A feature that's merely an alternative way to do the same thing isn't worth chasing. |
| New SQL Server version/feature changes cleanup or harness mechanics | `modules/reference/legacy-tsql-harness.md`, `modules/reference/integration/*.md` | Whether the transaction/rollback and FK-ordered-cleanup mechanics still hold. |
| A new mainstream .NET test framework gains real adoption (the way xUnit displaced MSTest/NUnit in many shops) | `modules/dotnet/unit-tests.md`, `modules/dotnet/integration-tests.md` | Add it as a **detected/followed** option in "detect first, default second" — this doesn't necessarily change the skill's own default, only what it recognizes and follows when already present. |
| .NET's build-time style-enforcement defaults change (e.g. a future SDK flips `EnforceCodeStyleInBuild`'s default) | `modules/reference/language-features-for-testability.md` | Re-verify the "EditorConfig and the two gates" section's claim about which gates default on/off. |
| Expanding to a new tech stack (Node, Python, etc.) | `SKILL.md` § Context routing, new `modules/<stack>/` folder | The router already supports this without restructuring — add `unit-tests.md`/`integration-tests.md` mirroring `modules/dotnet/` and one routing entry in `SKILL.md`. This row exists mainly to confirm nothing else needs touching. |
| E2E testing gets brought into scope | `SKILL.md` § Scope and failure behavior, new `modules/e2e/` | Same no-restructuring guarantee as above. |

## What does *not* need touching on a language/version bump

These are stable practices independent of tooling versions, and a version-driven update pass should not
reflexively touch them:

- `modules/foundation.md`'s band-pass filter model and "Choosing the level" section.
- The interview-first discovery/discussion workflow in `SKILL.md` and `modules/discovery.md`.
- `templates/scenario-doc-template.md`, `templates/testing-plan-template.md`,
  `templates/testability-notes-template.md`, `templates/modernization-handoff-template.md`.
- The DDD/F#-inspired entries in `modules/reference/design-smell-entries.md` that aren't tied to a specific
  C# version (illegal states representable, anemic domain models, mutable state by default, non-exhaustive
  branching, reference equality, exceptions as control flow) — these are modeling practices, not language
  features, and remain valid regardless of what ships next.
- `modules/reference/characterization-tests.md`, `modules/reference/legacy-seams.md`,
  `modules/reference/migration-testing.md` — Feathers' dependency-breaking techniques and the
  characterization/migration playbooks are language-version-agnostic.
