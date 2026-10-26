# Credentials

Load when setup adds servers that need authentication. Never collect a secret
in chat and never write one into the client config or Crow state.

## Preconditions (hard gate)

Do not run any credential script until both are true. Check with
`node scripts/crow-raven-setup.mjs status`:

1. **Raven source is present.** Crow setup obtains it (attested release bundle,
   or a pinned source clone as fallback). If `status` shows no Raven install,
   do not ask the user to clone anything: run the setup install step first,
   with the user's approval of the plan digest.
2. **The Raven runtime is installed and usable.** `raven.runtimePath` exists
   and contains `packages/auth/dist/load-env.js` (or
   `runtime/node_modules/@nrs/auth/dist/load-env.js`) and `dotenv`. If it is
   missing or incomplete, repair through setup (`check`, then the install
   step); never run the script and let it fail.

Tell the user why you are pausing: the credential script needs Raven's
runtime. Then continue the order: non-secret values and token creation can be
done while waiting for install approval; token entry, client config apply,
restart, and verification follow the install.

## Run the credential tool

The credential scripts ship in this skill's `scripts/` folder as Crow-modified
copies (see [raven-credential-scripts.md](raven-credential-scripts.md)). They need Raven's built auth
module, so always pass the installed runtime path from
`node scripts/crow-raven-setup.mjs status` (`raven.runtimePath`).

The agent supplies everything that is not a secret. The user is never asked
for a URL or email a second time and types only the token, into a hidden
prompt the agent never reads.

macOS, as a fenced block with `cd` first (never one long inline path: copying
an inline path can add a trailing space and fail with MODULE_NOT_FOUND):

```
cd <skill scripts path>
node setup-credentials-mac.mjs --raven-runtime <runtimePath> --sections atlassian --set ATLASSIAN_BASE_URL=<tenant url> --set ATLASSIAN_EMAIL=<email>
```

- `--sections` takes only the selected integrations (`atlassian`, `github`,
  `sonar`, `jenkins`, and so on) so no unrelated prompts appear.
- `--set` accepts non-secret fields only; the script refuses a secret passed
  as an argument.
- A blank Enter at the token prompt keeps the stored value, so tell the user
  to paste the token and then press Enter once.
- Windows: `scripts/setup-credentials.ps1` is still Raven's unmodified,
  fully interactive script; it has no `--set` or `--sections` yet.
- Linux: no interactive script; use the manual `~/.raven/.env` fallback below.

## Manual fallback (all OS, required on Linux)

Create `~/.raven/` with mode 700 and `~/.raven/.env` with mode 600. Quote any
value containing `#`, or it is silently truncated. Point the user to Raven's
README for the variable names per server.

## Per-server guides

Introduce one server at a time, only for servers the user selected. Load
[credentials-servers.md](credentials-servers.md) to map each selected server
to its guide in `servers/` (for example `jira` or `confluence` to
[servers/atlassian.md](servers/atlassian.md)), and load only that guide.
