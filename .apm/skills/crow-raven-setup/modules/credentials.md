# Credentials

Load when setup adds servers that need authentication. Never collect a secret
in chat and never write one into the client config or Crow state.

## Locate the credential tool

Resolve the script inside the installed Raven runtime (path from
`node scripts/crow-raven-setup.mjs status`, under `scripts/`):

- Windows: `setup-credentials.ps1`
- macOS: `setup-credentials-mac.mjs`
- Linux, or script absent: manual `~/.raven/.env` below.

Tell the user the exact command to run in their own terminal and what the
prompts will ask. Enter keeps a stored value; `:clear` erases one.

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
     open `https://id.atlassian.com/manage-profile/security/api-tokens`;
     choose a **Classic (non-scoped)** token, not the Granular wizard (scoped
     tokens return 401 because they need the `api.atlassian.com` gateway,
     which Raven does not support); name it and copy it; then continue to
     step 6.
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
