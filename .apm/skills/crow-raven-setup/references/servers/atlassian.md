# Atlassian (Jira and Confluence)

Load when the user selects `jira`, `confluence`, or both. They share one set
of credentials, so one run of the credential tool covers both. Run the
preconditions and command shape in [credentials.md](../credentials.md) first.

| Item | Value |
|---|---|
| `--sections` | `atlassian` |
| Non-secret (`--set`) | `ATLASSIAN_BASE_URL`, `ATLASSIAN_EMAIL` |
| Secret (hidden prompt) | Atlassian API token (Classic, not scoped) |
| Verify (read-only) | Jira `read_issue` on a known key; Confluence `list_spaces` |

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

```
cd <skill scripts path>
node setup-credentials-mac.mjs --raven-runtime <runtimePath> --sections atlassian --set ATLASSIAN_BASE_URL=<tenant url> --set ATLASSIAN_EMAIL=<email>
```

Tell the user to paste the token, then press Enter once.

A real first-time failure sequence to teach from: 404 on an internal path,
403 on the vanity host, 401 with a scoped token, success on the tenant URL
with `/wiki` and a Classic token. Each is a URL or token-type problem, not a
bad password.

## Verify

Restart the client first; servers read credentials once at startup. Then make
read-only calls: Jira `read_issue` on a key the user knows, and Confluence
`list_spaces`.

## Atlassian behind SiteMinder (internal)

Raven's README describes an internal Basic Auth host, not public, that
bypasses SiteMinder, or an SMSESSION browser fallback (Playwright Chromium,
session cached about 25 minutes). Direct the user to their team lead or the
Raven maintainer for the host; never guess one. Prefer the Cloud path when
the user has a tenant.
