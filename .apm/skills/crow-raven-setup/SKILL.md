---
name: crow-raven-setup
description: Guide selective setup and maintenance of Raven MCP servers and codebase-memory-mcp, including conditional SonarScanner CLI and .NET/MSBuild setup, freshness checks, explicit updates, and rollback.
---

# Crow Raven Setup

Use this skill when installing, configuring, checking, updating, or rolling
back Crow's Raven MCP server and codebase-memory-mcp dependencies.

## Context-efficient loading

1. Load [`references/foundation.md`](references/foundation.md) for every use.
   For a new user, no recorded setup state, or a request to learn or be guided,
   also load [`references/guided-onboarding.md`](references/guided-onboarding.md)
   and follow its interview before the workflow below.
2. Load [`assets/raven-servers.json`](assets/raven-servers.json) only
   when presenting or validating Raven server choices.
3. Load [`references/delivery-and-updates.md`](references/delivery-and-updates.md)
   when selecting a Raven distribution, checking freshness, or rolling back.
4. Load [`references/client-targets.md`](references/client-targets.md) when choosing
   or applying a client target, [`references/credentials.md`](references/credentials.md)
   when selected servers need authentication (it routes to the per-server
   guides in `references/servers/`), and
   [`references/verify-and-troubleshoot.md`](references/verify-and-troubleshoot.md)
   after applying configuration or on any connection or authentication error.
5. Load [`references/sonar-scanners.md`](references/sonar-scanners.md) only when
   Sonar MCP is active/configured or the `sonar` server is selected for the
   current setup, and scanner setup or maintenance is in scope.

## Workflow

1. Inspect existing state with `node scripts/crow-raven-setup.mjs status`
   and inspect the optional
   user-level Copilot update-hook decision with
   `node scripts/crow-raven-setup.mjs update-hook status` when the active
   client is Copilot Local, Copilot Agent Host, or Copilot CLI. When its
   decision is `pending`, offer the hook once and install it only after
   explicit user consent; persist a decline with `update-hook decline`. Do not
   repeat a recorded offer. If the decision is `missing`, ask whether to
   restore the previously enabled hook. If the decision is `recoverable`, the
   matching hook file exists but its persisted opt-in is missing; ask the user
   to confirm recovery, then run `update-hook install --confirm` before
   reporting it enabled. If `conflicting`, preserve the different file; after
   separate approval, use `update-hook replace --hook-sha256 <status digest>
   --confirm` and report the backup. The hook checks Crow, plus bundled
   Raven and codebase-memory-mcp when they are recorded in Crow Setup state;
   source-pinned Raven revisions remain covered by the setup freshness check.
   When setup state uses a non-default directory, pass
   `--setup-state-dir <path>` consistently to hook status, install, and removal
   commands. Skip this offer for non-Copilot or unknown clients.
   Detect an installed Sonar MCP from the active `sonar_run_scan` tool or the
   selected client's configured `sonar` (Crow/Raven catalog ID) or
   `sonar-mcp` server. A project's `crow.config.sonar` section alone is not
   evidence that the server is installed. If present, load
   `references/sonar-scanners.md` and inspect scanner versions, client launch
   environment, and .NET SDK version once. Do not install the SDK implicitly.
   Preserve a concise handoff record of client/path, catalog IDs,
   prerequisite and Sonar inventory, auth status, setup/hook state, approvals,
   plan digest, and remaining gates; retry only failed checks.
2. Validate exact requested IDs against the bundled catalog without asking
   for redundant selection confirmation. Confirm only lists derived from
   broader groups. If the user selects `sonar`, load
   `references/sonar-scanners.md` for the new installation even if the server is
   not yet configured in the client. Record an explicit `--no-raven` choice
   when the user wants only codebase-memory-mcp. Run `preflight --delivery
   release|source|none` (and `--sonar` when selected) once after selection;
   record paths/versions and GitHub CLI authentication. Stop before planning
   a release if `gh auth status` fails. Recheck only the changed prerequisite
   on retry; obtain separate approval before installing any prerequisite.
3. Use Raven's attested bundled release by default. Use `--delivery source`
   only as an explicit fallback. Generate the exact setup plan, present its
   SHA-256 digest and effects, and obtain confirmation bound to that unchanged
   plan.
4. Use `crow-raven-setup.mjs`; do not recreate its installation, version
   resolution, state, or fragment-generation logic in model-authored commands.
   This script manages Raven and codebase-memory-mcp only. The setup agent
   executes Sonar scanner commands with `execute` using
   `references/sonar-scanners.md`; keep its preview, confirmation, state, and
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
5. When setup adds servers that need authentication, follow
   `references/credentials.md`. Pass its preconditions gate first: Raven must be
   installed with a usable runtime (`status`), and if not, run the install step
   before any credential script. Then pick the credential path (Atlassian Cloud
   versus gov SiteMinder), collect non-secret values in chat, and run the
   skill's credential script with `--raven-runtime`, `--sections`, and `--set`.
   The user types only secrets into the hidden prompt; never collect secrets
   in chat.
6. When Sonar MCP is installed or `sonar` is selected in the current setup,
   use `references/sonar-scanners.md` to set up or update the generic SonarScanner
   CLI and, when a compatible .NET SDK is available, the .NET/MSBuild scanner.
   Execute only the confirmed plan and surface command errors.
7. Use `config preview` and separately approved `config apply
   --approval-sha256 <digest> --confirm` to merge into the active supported
   client. VS Code Copilot sessions and Copilot CLI use the same global
   `$COPILOT_HOME/mcp-config.json` (`~/.copilot/mcp-config.json` by default)
   with `mcpServers`; choose `--client copilot`. If VS Code has pending
   migration of old profile entries, let the editor finish migrating first,
   then preview global configuration and verify migrated or already installed
   entries rather than duplicating them. Never write profile `mcp.json` or
   `settings.json`. A different
   editor may use `--client portable --config <verified-path>` only when its
   documented schema is `mcpServers`; otherwise use its own native flow
   without inventing a write target. Stop on collisions, malformed files,
   or stale preview. A changed selected-name entry may be replaced only
   when it matches the verified previous Crow-managed fragment; preview
   replaced IDs and obtain approval for them too. Report backup and verify
   the result.
8. Verify per `references/verify-and-troubleshoot.md` in three levels
   (installed, configured, authenticated with a read-only call). Report
   authentication failures as failures. Verify selected servers and, when Sonar MCP is installed or selected,
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
- The report states installed, configured, and authenticated status
  separately; unauthenticated servers are listed, not hidden.
- When Sonar MCP is installed or selected, the generic scanner is verified;
  the .NET/MSBuild scanner is verified when a compatible SDK is available, or
  its missing prerequisite is reported. Unverified MCP visibility is reported.
