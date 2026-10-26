# Client Targets

Load when choosing where Raven servers are configured. Ask which client the
user wants to use; do not assume Copilot.

| Client | Supported by `config apply` | How |
|---|---|---|
| Copilot (VS Code, CLI, agent host) | Yes | `--client copilot`; global `$COPILOT_HOME/mcp-config.json` (`~/.copilot/mcp-config.json`) |
| Any client with a documented `mcpServers` JSON schema | Yes | `--client portable --config <verified-path>` |
| Claude Code, Codex, Cursor, Antigravity | Not yet | Use the client's own flow; show the generated fragment with `config preview` and do not invent a write target |

Treat the last row as a documented gap until `client-config.mjs` gains
verified targets. Confirm each client's schema against its current official
documentation before relying on it.

## Per-OS notes

- **macOS:** credential script `scripts/setup-credentials-mac.mjs` (login
  keychain). Playwright Chromium may be needed; see `credentials.md`.
- **Windows:** credential script `scripts/setup-credentials.ps1` (DPAPI).
- **Linux:** no interactive credential script; use `~/.raven/.env` with mode
  600 as described in `credentials.md`.

## After applying

Remind the user to fully restart the client; servers do not load until it
does. Then run the checks in `verify-and-troubleshoot.md`.
