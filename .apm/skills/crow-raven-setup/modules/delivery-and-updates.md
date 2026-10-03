# Raven Delivery and Update Policy

## Current delivery choices

### 1. Attested bundled runtime release (default)

Raven publishes a SemVer release of the tested suite with platform archives,
native launchers, a bundled Node runtime, production dependencies, a versioned
server catalog, SPDX SBOMs, source commit metadata, clean-runner smoke results,
and GitHub build attestations. Crow verifies the archive digest, GitHub
attestation, and embedded metadata before promoting the staged runtime.

SHA-256 files provide corruption detection but are not publisher
authentication. Crow should trust a release only after verifying its signed
manifest or provenance against a documented publisher identity.

A suite version is the simplest near-term compatibility contract. The catalog
should still carry per-server versions so Raven can split lifecycles later
without changing Crow's selection model.

### 2. Pinned source revision (explicit fallback)

When a Raven release does not support the current platform, or the user
explicitly requests source delivery, Crow may clone an immutable commit into a
versioned user-local directory, run `npm ci`, build it, and generate launch
entries for selected servers. This requires a local toolchain and executes
dependency lifecycle scripts, so disclose its lower assurance and obtain
confirmation. Never fall back silently.

Pin the commit, lockfile, and supported Node version. Build a new directory
before switching state; never update the active checkout in place.

## Raven release contract

- Raven's current public runtime and catalog contract starts at `0.1.0` and
  remains pre-stable; do not infer stability from repository age.
- Tag releases as `v<version>` and publish immutable assets from that tag.
- Version the suite, every server, and the catalog schema explicitly.
- Produce a signed manifest containing artifact digest, source commit, server
  ID, launcher, protocol compatibility, runtime requirements, permissions,
  deprecation state, and security status.
- Publish provenance and an SBOM from protected CI, and make release assets
  immutable.
- Define support, security-fix, deprecation, and rollback windows before a
  stable `1.0.0`.

## Freshness and updates

Updates are checked at invocation time, not by a resident process:

- the Raven `check` command checks at most once every 24 hours based on its
  user-local state;
- allow an explicit `--force` check;
- use short network timeouts and report offline or rate-limit failures;
- record only the timestamp and resolved public versions;
- do not send telemetry;
- notify about available changes but never apply them automatically.

The Raven `check` command writes its 24-hour timestamp only after the checks
complete successfully. An APM lookup failure therefore remains eligible for a
retry instead of suppressing checks for a day.

An optional, user-level Copilot hook can check for updates while the user works
with agents. The Raven Setup Agent offers it once; the hook is installed only
after explicit consent. It uses Copilot's user hook directory (`~/.copilot/hooks`
or `$COPILOT_HOME/hooks`) and runs on submitted prompts. It checks Crow's latest
stable GitHub release and, when recorded as installed in Crow Setup state,
Raven's latest stable release and codebase-memory-mcp's npm `latest` version.
For Raven, this release check applies to the bundled-release delivery; use the
Raven Setup Agent's freshness check for pinned-source revisions. Without Crow
Setup state, the hook checks Crow only.

Checks run at most once every 24 hours. If one release source fails, updates
found from the other sources are still reported, and the failed source is
retried after about one hour. The hook reads setup state without rewriting the
managed MCP fragment. It stores its decision, timestamps, and resolved public
versions in `~/.crow/update-check`; no scheduled task is required or installed,
and no update is applied automatically. When Crow Setup uses a non-default
state directory, pass `--setup-state-dir <path>` to `update-hook install` and
use that same argument for later hook status or removal commands. On Windows,
Copilot CLI hooks require PowerShell 7 or later in `PATH`. Restart Copilot CLI
after installing or changing the hook because user-level hooks load at startup.
To run a manual check from the Crow package root:

```text
node .apm/skills/crow-raven-setup/scripts/crow-raven-setup.mjs update-check --force
```

Append `--setup-state-dir <path>` when Crow Setup state is stored outside its
default `~/.crow/raven-setup` directory.

When `apm outdated --global` reports a newer Crow release, `apm update --global`
still follows the selector in the global APM manifest. An exact tag such as
`#v0.10.2` is a fixed ref, so APM can report a newer release without changing
the pin.

Crow's `stable` branch follows the latest published stable release. It is
initialized from the latest published release after a successful main-branch
asset validation, then advanced only after a stable GitHub release is
published; drafts, prereleases, and unreleased commits do not advance it. To
migrate an exact-pinned global Copilot install and enable future updates, run:

```powershell
apm install 'bcgov/crow#stable' --global --target copilot
```

After migration, `apm update --global --target copilot` resolves the current
published stable branch. The command `apm install bcgov/crow` without a ref
follows the repository's default branch and can include unreleased changes;
exact version tags remain fixed. For a collection install, use that
collection's package path with `#stable`. `apm self-update` updates the APM
CLI itself, not Crow. Installs managed outside APM, such as a direct Copilot
plugin install, require their corresponding updater.

Before a Raven dependency update, show the old and new immutable versions,
trust level, selected servers, configuration impact, and rollback target.
Build and verify the replacement before switching the fragment and state.
Retain at least the previous verified runtime. Rollback must restore both
runtime selection and generated configuration, then rerun verification.
