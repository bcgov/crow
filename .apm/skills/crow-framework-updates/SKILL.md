---
name: crow-framework-updates
description: Update language runtimes, SDKs, and primary application frameworks using verified support lifecycles, compatibility evidence, migration planning, and project-native checks.
---

# Framework and Runtime Updates

Use this skill when the requested changes target a language runtime, SDK, or
primary application framework. Identify components by their role in the
application, not by whether the target version is major, minor, or patch.
Routine third-party libraries and development tools belong to
[`crow-dependency-updates`](../crow-dependency-updates/SKILL.md).

## Workflow

1. Inventory every version source that affects the target: project manifests,
   SDK pins, container base images, build files, and CI configuration. Check
   repository architecture and deployment constraints before changing a
   runtime or framework.
2. Verify the current and proposed release lines, support dates, and
   migration requirements using official vendor documentation and release
   notes. Record exact versions and dates; do not infer support from a package
   manager's "latest" column alone.
3. Identify incompatible APIs, configuration changes, minimum runtime
   requirements, and affected application or test projects. For a major
   migration, present a bounded plan and ask for confirmation before editing
   when the request does not already authorize that migration.
4. In a scheduled or unattended run, update only non-breaking patch/minor
   releases on a supported line. Defer major migrations, ambiguous release
   choices, changes needing user decisions, and components without a passing
   relevant baseline build/test without prompting.
5. Apply related runtime, framework, container, and CI version changes
   coherently in a component-sized batch. Regenerate lockfiles with the
   repository's pinned package manager and toolchain; do not use force or
   bulk-upgrade options to bypass compatibility review. In unattended mode,
   capture the exact pre-update contents of files before editing; defer if
   doing so would overwrite pre-existing work.
6. Run the repository's affected build and test commands. If unattended
   verification fails, restore only that component's changes to the captured
   pre-update contents, verify the restore, and stop further updates. Never
   use a broad reset or discard unrelated user changes. If the restore cannot
   be verified, stop and report the remaining changed files. Report exact
   commands and results, including baseline failures, unavailable tools, and
   any migration steps left incomplete.

For structural changes, load the applicable
[`crow-application-architecture`](../crow-application-architecture/SKILL.md)
and [`crow-application-development`](../crow-application-development/SKILL.md)
guidance. Use [`crow-testing`](../crow-testing/SKILL.md) to select verification
when an upgrade changes application behavior or test infrastructure. Before
reading `crow.config`, use
[`crow-project-context`](../crow-project-context/SKILL.md).

## Completion Gate

- The target runtime/framework and all related version pins are identified.
- Official support and migration evidence is recorded.
- Breaking changes were confirmed interactively or deferred in unattended
  mode.
- Builds and tests were run and their outcomes are accurately reported.
