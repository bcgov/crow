---
name: crow-raven-setup
description: Guide selective setup and maintenance of Raven MCP servers and codebase-memory-mcp, including conditional SonarScanner CLI and .NET/MSBuild setup, freshness checks, explicit updates, and rollback.
---

# Crow Raven Setup

Use this skill when installing, configuring, checking, updating, or rolling
back Crow's Raven MCP server and codebase-memory-mcp dependencies.

## Context-efficient loading

1. Load [`modules/foundation.md`](modules/foundation.md) for every use.
2. Load [`resources/raven-servers.json`](resources/raven-servers.json) only
   when presenting or validating Raven server choices.
3. Load [`modules/delivery-and-updates.md`](modules/delivery-and-updates.md)
   when selecting a Raven distribution, checking freshness, or rolling back.
4. Load [`modules/sonar-scanners.md`](modules/sonar-scanners.md) only when
   Sonar MCP is active/configured or the `sonar` server is selected for the
   current setup, and scanner setup or maintenance is in scope.

## Workflow

1. Inspect prerequisites and existing state with
   `node scripts/crow-raven-setup.mjs status`, and inspect the optional
   user-level Copilot update-hook decision with
   `node scripts/crow-raven-setup.mjs update-hook status` when the active
   client is Copilot Local, Copilot Agent Host, or Copilot CLI. When its
   decision is `pending`, offer the hook once and install it only after
   explicit user consent; persist a decline with `update-hook decline`. Do not
   repeat a recorded offer. If the decision is `missing`, ask whether to
   restore the previously enabled hook. If the decision is `recoverable`, the
   matching hook file exists but its persisted opt-in is missing; ask the user
   to confirm recovery, then run `update-hook install --confirm` before
   reporting it enabled. The hook checks Crow, plus bundled
   Raven and codebase-memory-mcp when they are recorded in Crow Setup state;
   source-pinned Raven revisions remain covered by the setup freshness check.
   When setup state uses a non-default directory, pass
   `--setup-state-dir <path>` consistently to hook status, install, and removal
   commands. Skip this offer for non-Copilot or unknown clients.
   Detect an installed Sonar MCP from the active `sonar_run_scan` tool or the
   selected client's configured `sonar` (Crow/Raven catalog ID) or
   `sonar-mcp` server. A project's `crow.config.sonar` section alone is not
   evidence that the server is installed. If present, load
   `modules/sonar-scanners.md` and inspect scanner versions, client launch
   environment, and .NET SDK version. Do not install the SDK implicitly.
2. Resolve server selection through focused user questions and validate IDs
   against the bundled catalog. If the user selects `sonar`, load
   `modules/sonar-scanners.md` for the new installation even if the server is
   not yet configured in the client. Record an explicit `--no-raven` choice
   when the user wants only codebase-memory-mcp.
3. Use Raven's attested bundled release by default. Use `--delivery source`
   only as an explicit fallback. Generate the exact setup plan, present its
   SHA-256 digest and effects, and obtain confirmation bound to that unchanged
   plan.
4. Use `crow-raven-setup.mjs`; do not recreate its installation, version
   resolution, state, or fragment-generation logic in model-authored commands.
   This script manages Raven and codebase-memory-mcp only. The setup agent
   executes Sonar scanner commands with `execute` using
   `modules/sonar-scanners.md`; keep its preview, confirmation, state, and
   rollback separate from the script's plan.
   Its `check` command also reports an outstanding global APM update for Crow
   when Crow is APM-managed; it never applies that update. If `apm outdated`
   reports a newer Crow release but `apm update --global` leaves an exact-pinned
   install unchanged, explain that the exact tag is fixed. After confirmation,
   migrate the same installed selector to Crow's release-maintained branch by
   appending `#stable`: use `bcgov/crow#stable` for the full package,
   `bcgov/crow/collections/starter-package#stable` for that collection, or
   `bcgov/crow/collections/security-remediation#stable` for that collection.
   Do not add the full package to update a collection. Later,
   `apm update --global --target copilot` follows published stable releases.
5. Configure credentials only through Raven's official user-local mechanism.
6. When Sonar MCP is installed or `sonar` is selected in the current setup,
   use `modules/sonar-scanners.md` to set up or update the generic SonarScanner
   CLI and, when a compatible .NET SDK is available, the .NET/MSBuild scanner.
   Execute only the confirmed plan and surface command errors.
7. Merge generated entries into a client only with confirmation, preserving
   unrelated entries and stopping on collisions.
8. Verify selected servers and, when Sonar MCP is installed or selected,
   scanner versions and client PATH configuration. Verify the .NET scanner
   only when the compatible SDK is available. On every subsequent setup or
   maintenance invocation, check for newer compatible stable scanner releases
   and offer updates for confirmation. Report delivery assurance, versions,
   the previous rollback target, and any failed checks.

Run `node scripts/crow-raven-setup.mjs help` for the command contract.

## Completion gate

- Selection is explicit and catalog-valid.
- Raven release provenance is verified (or source fallback is immutable), and
  package versions are exact.
- State and generated configuration contain no credentials.
- Existing client configuration is preserved.
- Setup or maintenance verification succeeds without hidden fallback.
- When Sonar MCP is installed or selected, the generic scanner is verified;
  the .NET/MSBuild scanner is verified when a compatible SDK is available, or
  its missing prerequisite is reported. Unverified MCP visibility is reported.
