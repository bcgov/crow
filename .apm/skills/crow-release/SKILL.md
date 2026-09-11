---
name: crow-release
description: Prepare, validate, package, and publish a Crow version through GitHub Releases with explicit semantic-version and major-release decision gates.
---

# Crow Release

Use this skill when preparing or publishing a Crow release.

## Required context

1. Read [`modules/versioning.md`](modules/versioning.md).
2. Read `../crow-agent-skill-authoring/modules/public-release.md`.
3. Read `../crow-project-context/SKILL.md` and `crow.config` when present to
   identify existing public CI/CD and release references. Never copy private
   pipeline URLs or credentials into the repository.
4. Read [`templates/release-notes-template.md`](templates/release-notes-template.md).
5. Inspect the complete release diff and the latest published tag.
6. Do not load unrelated domain modules.

## Release notes standard

Use `templates/release-notes-template.md` as the starting structure for every
release draft. Replace every `{{PLACEHOLDER}}`, remove unused bullets, and
retain the following stable contract:

- title: `BCGov Crow - v<version>`;
- release type and concise summary;
- highlights or changes;
- validation results;
- exactly the versioned ZIP and SHA-256 artifacts;
- installation instructions;
- compatibility and upgrade notes when relevant.

The tag, title, archive name, checksum filename, and version must agree. Do not
copy generated release text without reviewing it for internal URLs, credentials,
environment-specific paths, private repository names, or unsupported claims.

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

The approval-gated draft workflow is implemented in
[crow-release-draft.yml](../../../.github/workflows/crow-release-draft.yml).
It follows successful main-branch asset validation, prepares a candidate from
the exact validated commit, pauses at the protected `release` environment, then
rebuilds and creates a verified GitHub draft release after approval. Configure
required reviewers for the `release` environment before enabling tag creation.
The workflow uses
[`New-CrowReleaseDraft.ps1`](scripts/New-CrowReleaseDraft.ps1) for deterministic
version, provenance, packaging, checksum, tag, and draft-release checks.
The workflow pins the APM installer to an immutable commit and verifies its
SHA-256 before execution. Checkout credentials are not persisted; the final
tag push receives a scoped token only for the release step.

## Approval-gated draft release

The implemented workflow uses `workflow_run` to identify
the exact validated `main` commit, builds and validates the archive, and stores
the rendered notes, checksum, version, and source commit SHA as workflow
artifacts. A protected `release` environment then requires an explicit
maintainer approval before a second job:

1. Confirms the approved version still matches `apm.yml` on `main`.
2. Verifies the triggering run belongs to this repository, was completed
   successfully for `main`, and has the exact approved commit SHA.
3. Checks out that immutable commit SHA and rebuilds the ZIP, notes, and
   checksum in the protected job. Do not trust uploaded executable content as
   the release source; uploaded artifacts may be compared against the rebuild
   only after their SHA-256 and source SHA are verified.
4. Re-runs the asset validator, package dry run, archive inspection, exact
   version-consistency checks, and release guards immediately before tag or
   release creation.
5. Creates and pushes the annotated `v<version>` tag if it is absent, failing
   closed if another run creates it concurrently.
6. Creates the GitHub release as a draft with the standard title, rendered
   notes, ZIP, and checksum.
7. Verifies the draft release and uploaded asset names and digests.

Release notes may be supplied as reviewed input. When no reviewed notes are
provided, the draft script generates notes from the validated release commit
subjects and current artifact values; it does not embed a version-specific
release narrative in reusable code.

This workflow adds a human decision point before tag creation and draft-release
creation. It must not infer a version from a branch name, silently overwrite
an existing tag or release, accept a lightweight tag, publish a draft
automatically, or place private provider values in release notes.

## Release validation sequence

Run the following checks against the exact release commit before approving or
publishing a draft:

1. Resolve the public-safe project configuration and release version.
2. Run the Crow asset validator and the complete Crow release test suite.
3. From the local agent session, run a Sonar scan using the
   `crow-sonar-scan` skill for the exact release branch and commit, then query
   the matching quality gate. Record only the project, branch, version, scan
   status, quality-gate status, and timestamp in session-local release evidence.
   Never put Sonar URLs, credentials, tokens, or provider responses in release
   notes, workflow files, package metadata, or the repository.
4. Run the APM package dry run, build the archive, calculate its SHA-256
   checksum, and inspect archive contents.
5. Verify the exact commit, version references, candidate provenance, annotated
   tag, draft title, draft state, and two expected asset names.

GitHub-hosted workflows do not run Sonar because the SonarQube server is
internal and inaccessible from GitHub runners. If the local Sonar MCP server or
quality-gate result is unavailable, stop the release validation rather than
treating the scan as successful.

## Completion gate

- Version classification matches the full diff.
- A major version was explicitly chosen by the user.
- Manifests and README versions agree.
- Release notes use the standard template and the title, tag, archive, and
  checksum names agree.
- Local agent Sonar scan completed for the exact release commit, its quality
  gate passed, and the result was collected in session-local evidence.
- Validation, package dry run, specialist review, and rubber-duck review pass.
- Worktree and release commit are clean and pushed.
- Archive contents are inspected and contain no evidence or local state.
- Artifact provenance, protected publishing, and checksum verification protect the package supply chain; they do not by themselves prove enterprise Zero Trust implementation.
- SHA-256 checksum exists.
- Any automated draft workflow is duplicate-safe, least-privilege, and stops
  before publication.
- The approval-gated workflow checks out and rebuilds the exact validated
  commit, and the `release` environment has required reviewers configured.
- Publishing occurs only after explicit user approval.
- The GitHub release and uploaded assets are verified after creation.
