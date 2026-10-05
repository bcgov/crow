---
name: crow-dependency-updates
description: Perform recurring, scope-limited updates of third-party libraries, plugins, and development tools using exact package-manager evidence, lockfile integrity, and compatibility checks.
---

# Third-Party Dependency Updates

Use this skill for libraries, plugins, and development tools. Language
runtimes, SDKs, and primary application frameworks belong to
[`crow-framework-updates`](../crow-framework-updates/SKILL.md), including
patch/minor releases of those components.

## Workflow

1. Load [`modules/package-managers.md`](modules/package-managers.md). Inspect
   repository roots, manifests, lockfiles, wrappers, toolchain pins, build
   scripts, and CI restore commands; route each project to its owning manager
   and only the matching technology sections in the catalog. Respect workspace
   boundaries, version ranges, and existing update policies.
2. Query the repository's native package manager or an authoritative package
   registry for exact available stable versions. Do not infer current versions
   from lockfiles, silently select prereleases, or change package sources.
3. Classify each candidate by compatibility and change size. In scheduled or
   unattended runs, apply only non-breaking patch/minor updates and defer
   components without a passing relevant baseline build/test; defer major or
   ambiguous changes without prompting. In interactive runs, ask before
   breaking upgrades, dependency replacements, or changes to licensing or
   package sources.
4. Update one component-sized batch of scoped declarations and regenerate
   lockfiles with the repository's pinned package manager. Avoid force
   upgrades and bulk `audit fix` commands that can cross the requested scope.
   In unattended mode, capture the exact pre-update contents of each file
   before editing; defer if doing so would overwrite pre-existing work.
5. Run available ecosystem-native advisory checks for the updated dependency
   set. If a check or registry is unavailable, state that explicitly; do not
   claim that the resulting versions are vulnerability-free.
6. Run relevant builds and tests. If unattended verification fails, restore
   only that component's changes to the captured pre-update contents, verify
   the restore, and stop further updates. Never use a broad reset or discard
   unrelated user changes. If the restore cannot be verified, stop and report
   the remaining changed files. Then report exact versions, changed manifests
   and lockfiles, evidence sources, verification results, and any skipped or
   blocked updates.

Use [`crow-application-development`](../crow-application-development/SKILL.md)
when an update requires application-code migration. Use
[`crow-testing`](../crow-testing/SKILL.md) for test selection when behavior or
test infrastructure changes. Before reading `crow.config`, use
[`crow-project-context`](../crow-project-context/SKILL.md).

This skill supports routine maintenance independently of security-review
reports and tickets. A request specifically to remediate a security finding
must use a security-remediation workflow; report discovered advisories without
claiming that those findings have been remediated.

## Completion Gate

- Every changed package is in scope and has an exact, evidence-backed target
  version.
- Package manager and lockfile state are consistent.
- Advisory checks, builds, and tests were run where available, with failures
  and gaps reported explicitly.
