---
name: crow-release
description: Prepare, validate, package, and publish a Crow version through GitHub Releases with explicit semantic-version and major-release decision gates.
---

# Crow Release

Use this skill when preparing or publishing a Crow release.

## Required context

1. Read [`modules/versioning.md`](modules/versioning.md).
2. Read `../crow-agent-skill-authoring/modules/public-release.md`.
3. Inspect the complete release diff and the latest published tag.
4. Do not load unrelated domain modules.

## Prepare a version

1. Classify the complete release diff and apply user-decision gates from [`modules/versioning.md`](modules/versioning.md).
2. Run:

   ```powershell
   & .\.apm\skills\crow-release\scripts\Set-CrowVersion.ps1 -Bump Minor
   ```

   Use `Patch` or `Major` as appropriate. `Major` also requires `-ConfirmMajor`.
3. Review the version-only edits, run the Crow asset validator, run `apm pack --dry-run`, and complete the Crow agent/skill review plus rubber-duck review.
4. Commit and merge the prepared version through the repository's normal review process.

## Package and publish

Run publication only from the intended release commit on the default branch with a clean worktree:

```powershell
& .\.apm\skills\crow-release\scripts\Publish-CrowRelease.ps1 -Version 0.3.0
```

Without `-Publish`, the script validates and packages the archive, writes its SHA-256 checksum, and reports the exact GitHub release action without creating a release.

After the user explicitly approves publication, rerun with `-Publish`. For a major version, also pass `-ConfirmMajor`.

The publish script requires an existing remote tag and uses `gh release create --verify-tag --generate-notes --fail-on-no-commits`. It uploads both the package archive and checksum file. Never create or move a release tag implicitly.

## Completion gate

- Version classification matches the full diff.
- A major version was explicitly chosen by the user.
- Manifests and README versions agree.
- Validation, package dry run, specialist review, and rubber-duck review pass.
- Worktree and release commit are clean and pushed.
- Archive contents are inspected and contain no evidence or local state.
- SHA-256 checksum exists.
- Publishing occurs only after explicit user approval.
- The GitHub release and uploaded assets are verified after creation.
