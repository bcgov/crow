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

The default is an invocation-time check, not a resident process:

- check at most once every 24 hours based on user-local state;
- allow an explicit `--force` check;
- use short network timeouts and report offline or rate-limit failures;
- record only the timestamp and resolved public versions;
- do not send telemetry;
- notify about available changes but never apply them automatically.

An OS-native daily scheduler is opt-in and separately confirmed. It may run
only the notification check, must have a documented removal command, and must
not hold credentials or perform upgrades.

Before an update, show the old and new immutable versions, trust level,
selected servers, configuration impact, and rollback target. Build and verify
the replacement before switching the fragment and state. Retain at least the
previous verified runtime. Rollback must restore both runtime selection and
generated configuration, then rerun verification.
