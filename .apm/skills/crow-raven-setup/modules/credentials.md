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
4. **Warn on vanity domains** such as `*.gov.bc.ca` (for example
   `wiki.justice.gov.bc.ca`). They sit behind SiteMinder and reject API
   tokens with 403 ("caller cannot access Confluence"). Ask for the tenant
   URL instead.
5. **Token type:** create a **Classic (non-scoped)** API token at
   `https://id.atlassian.com/manage-profile/security/api-tokens`. Do not use
   the Granular/Scoped wizard: scoped tokens return 401 on tenant URLs
   because they need the `api.atlassian.com` gateway, which Raven does not
   support.
6. **Enter the token only through the credential tool**, never in chat. Give
   the user the URL and email to type into its prompts.

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
