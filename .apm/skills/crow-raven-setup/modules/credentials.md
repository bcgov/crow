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
copies (see `scripts/RAVEN-CREDENTIAL-SCRIPTS.md`). They need Raven's built auth
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

## Atlassian Cloud (verified path)

Collect the non-secret values in chat, then keep the token out of chat.

1. **Ask first: "Do you know your Atlassian Cloud URL?"** Example:
   `https://ag-isb.atlassian.net`. If not, tell the user to open Jira in a
   browser and copy the `https://<tenant>.atlassian.net` part of the address.
2. **Derive and echo back** both endpoints for confirmation, using the tenant
   URL the user gave:
   - Jira: `https://<tenant>.atlassian.net`
   - Confluence: `https://<tenant>.atlassian.net/wiki` (the `/wiki` suffix is
     required).
3. **Ask for the account email** used on that Atlassian site. Email is not a
   secret, so chat is fine.
4. **Validate the host before using it.** For the Cloud path it must end in
   `.atlassian.net`. Anything else, for example
   `https://wiki.justice.gov.bc.ca/wiki` or any `*.gov.bc.ca` host, is
   wrong: those sit behind SiteMinder and reject API tokens with 403
   ("caller cannot access Confluence"), and adding `/wiki` does not fix it.
   Say so plainly, do not accept the value, and ask for the
   `https://<tenant>.atlassian.net` address instead. Also strip a trailing
   path the user typed (such as `/wiki` or `/jira`) before deriving the two
   endpoints.
5. **Ask one short question: "To do this you'll need an Atlassian API token.
   Do you already have a Classic API token?"** Do not show the how-to up front.
   - **Yes:** do not ask for it. Say it goes into the credential tool, not
     chat, and give the one command to run (step 6).
   - **No, or unsure:** ask "Want me to walk you through creating one?" and
     if yes, give one step per turn, waiting for "done" between steps:
     1. Open `https://id.atlassian.com/manage-profile/security/api-tokens`
        and sign in with the account email.
     2. Click **Create API token**. Do **not** click "Create API token with
        scopes": scoped tokens return 401 because they need the
        `api.atlassian.com` gateway, which Raven does not support.
     3. On the next page, give the token a name (for example `raven-mcp`) and
        an expiration date. Recommend 1 year.
     4. Click **Create**, then **Copy**. Atlassian shows the token only once.
     5. Save it in a password manager now. Warn that it is a secret: it acts
        as the user, must not be shared with anyone, pasted into chat, email
        or tickets, or committed to a repository. If it leaks, revoke it on
        the same page.
6. **Enter the token only through the credential tool**, never in chat. Give
   the single command, and tell the user the URL and email to type at its
   prompts.

A real first-time failure sequence to teach from: 404 on an internal path,
403 on the vanity host, 401 with a scoped token, success on the tenant URL
with `/wiki` and a Classic token. Each is a URL or token-type problem, not a
bad password.

## Atlassian behind SiteMinder (internal)

Raven's README describes an internal Basic Auth host, not public, that
bypasses SiteMinder, or an SMSESSION browser fallback (Playwright Chromium,
session cached about 25 minutes). Direct the user to their team lead or the
Raven maintainer for the host; never guess one. Prefer the Cloud path when
the user has a tenant.

## Other servers

Introduce one at a time, only for servers the user selected. Point to the
server's section in Raven's README for the variables it needs.
