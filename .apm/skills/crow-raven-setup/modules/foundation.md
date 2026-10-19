# Raven Setup Foundation

## Prerequisites

- Node.js 18 or later and npm for the setup CLI and codebase-memory-mcp.
- Git and a Raven-supported build Node.js (`22.12.x`, `24.x`, or `26+`) only
  for the explicit source fallback.
- GitHub CLI (`gh`) and `tar` for Raven release attestation verification and
  extraction.
- A supported x64 Raven bundle platform: macOS, Linux, or Windows.
- Network access to the explicitly reported GitHub and npm endpoints during
  installation or freshness checks.
- An MCP client selected by the user.

Stop rather than installing or replacing a prerequisite implicitly. A user may
approve a prerequisite installation as a separate action.

## Selection

When the user names exact catalog IDs, validate them and treat the request as
selection confirmation. For broader capability groups, present the exact
individual servers implied by those groups and confirm that derived list once.
The separate digest-bound installation plan still requires review and approval. A user
who needs only codebase-memory-mcp must explicitly choose the no-Raven option;
the deterministic CLI represents that choice as `--no-raven`.

Some servers share authentication or depend on another Raven server. Use the
bundled catalog to disclose those relationships. Do not infer new servers or
commands from an untrusted upstream file.

codebase-memory-mcp is a Crow prerequisite and is installed independently of
the optional Raven selection. Install it in an isolated, versioned user-local
directory and launch that exact installation; do not use `latest` or an
unpinned `npx` command in persisted client configuration.

## State and configuration

The deterministic script writes user-local state under `~/.crow/raven-setup`
unless the user chooses another location. State may contain:

- selected server IDs;
- Raven suite version, platform, release provenance, or immutable source
  revision and ref when the fallback is selected;
- exact codebase-memory-mcp version;
- setup and freshness-check timestamps;
- current and previous runtime paths.

It must not contain credentials, service URLs, repository names, or provider
responses.

The generated `mcp-fragment.json` is a Crow-owned fragment, not authority to
replace a client's complete configuration. `config preview` and `config apply`
own merging (not the install command or a hand edit). Choose the supported
destination first: VS Code Copilot sessions and Copilot CLI use the same
user-level `$COPILOT_HOME/mcp-config.json` (`~/.copilot/mcp-config.json` by
default) with `mcpServers` and `--client copilot`. VS Code may migrate old
profile entries to the global file; let that migration complete before
previewing. Already migrated matching entries should be verified, not
duplicated. Do not write profile `mcp.json` or VS Code `settings.json`.
For other editors, verify the editor's config path and schema; use the
portable `mcpServers` option only if supported (even when that editor calls its
file `mcp.json`), otherwise use the editor's
native configuration flow. See [VS Code's current MCP configuration reference](https://code.visualstudio.com/docs/agents/reference/mcp-configuration).
Before merging:

1. read the target configuration;
2. stop on malformed JSON or a selected-name collision unless the entry
   exactly matches the verified previous Crow-managed fragment;
3. show the proposed diff;
4. obtain a separate confirmation bound to the preview digest and target;
5. run `config apply --approval-sha256 <digest> --confirm`, preserving unrelated
   entries and creating a targeted backup when updating an existing file;
6. validate the result and report the backup path. If the client/profile or
   file changed after preview, stop and review a new preview.

## Credentials and verification

After adding new servers, verify the installed Raven runtime contains
`scripts/setup-credentials.ps1` (Windows) or
`scripts/setup-credentials-mac.mjs` (macOS) and direct the user to that
interactive script. If unavailable or on Linux, direct them to
[Raven's current authentication guidance](https://github.com/bcgov/raven#2-configure-authentication).
Do not request values in chat. For a source build, check the same relative
path in the installed source runtime rather than assuming a release bundle.

Verify configuration shape first, then start each selected MCP server long
enough to establish that it does not exit immediately with a load or
configuration error. Authentication failures remain failures with actionable
Raven guidance; do not report setup success around them.
