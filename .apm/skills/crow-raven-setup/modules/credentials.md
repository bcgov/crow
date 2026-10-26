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

## Atlassian: choose the right path first

Ask which kind of site the user has before asking for any value.

| Site | Typical base URL | Credential |
|---|---|---|
| Atlassian Cloud | `https://<org>.atlassian.net`; Confluence needs the `/wiki` suffix | Account email plus API token |
| BC Gov SiteMinder-protected | Internal host, sometimes with a path such as `/int/...` | IDIR email and password through the internal Basic Auth host, or the SMSESSION browser fallback (Playwright Chromium, session cached about 25 minutes) |

Raven's README says the internal Basic Auth hostname is not public; direct the
user to their team lead or the Raven maintainer rather than guessing a URL.

A real first-time failure sequence to teach from: 404 on an internal path,
403 on the site root, success on the Cloud URL with `/wiki`. Each is a URL or
site-type problem, not a bad password.

## Other servers

Introduce one at a time, only for servers the user selected. Point to the
server's section in Raven's README for the variables it needs.
