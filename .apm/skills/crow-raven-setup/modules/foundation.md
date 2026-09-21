# Raven Setup Foundation

## Prerequisites

- Git.
- Node.js supported by Raven (`22.12.x`, `24.x`, or `26+`) and npm.
- Network access to the explicitly reported GitHub and npm endpoints during
  installation or freshness checks.
- An MCP client selected by the user.

Stop rather than installing or replacing a prerequisite implicitly. A user may
approve a prerequisite installation as a separate action.

## Selection

Present capability groups first to avoid a long undifferentiated checklist,
then show the exact individual servers implied by those groups. The individual
server list is authoritative and must be confirmed before installation. A user
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
- immutable Raven revision and source ref;
- exact codebase-memory-mcp version;
- setup and freshness-check timestamps;
- current and previous runtime paths.

It must not contain credentials, service URLs, repository names, or provider
responses.

The generated `mcp-fragment.json` is a Crow-owned fragment, not authority to
replace a client's complete configuration. Before merging:

1. read the target configuration;
2. stop on malformed JSON or a selected-name collision with a non-Crow entry;
3. show the proposed diff;
4. obtain confirmation;
5. preserve unrelated entries and create a targeted backup;
6. validate the result and report the backup path.

## Credentials and verification

Use Raven's supported OS-encrypted credential setup where available. If the
user elects the environment-file fallback, direct them to Raven's current
documentation without requesting values in chat.

Verify configuration shape first, then start each selected MCP server long
enough to establish that it does not exit immediately with a load or
configuration error. Authentication failures remain failures with actionable
Raven guidance; do not report setup success around them.
