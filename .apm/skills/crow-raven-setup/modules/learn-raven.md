# Learn Raven

Teaching content for the guided path. Source of truth is Raven's README and
`docs/TOOL_INVENTORY.md`; if this page disagrees with the installed runtime,
trust the runtime and say so.

## What Raven is

Raven is a set of MCP servers that let an AI assistant read and act on
workplace systems (Jira, Confluence, Bitbucket, Jenkins, Sonar, SharePoint,
GitHub and others) as the signed-in user. It sees only what that user can see.
Each server runs locally over stdio; the client launches it.

## How it is organised

Read `resources/raven-servers.json` and group servers by `group`:

- **Atlassian group** (Jira, Confluence, Bitbucket, Assets, Overview, Health,
  Bug Classifier): one shared authentication session; log in once.
- **Separately authenticated servers** (Server Monitor, IMIS, Azure DevOps,
  Jarvis, Sonar, Jenkins, Artifactory, RFC Buddy, SharePoint, GitHub): each
  has its own credentials.

Show `access` (read-only or read-write) so the user knows which servers can
change data.

## Where things live

| Item | Location |
|---|---|
| Raven runtime | Path recorded in Crow Setup state (`status`) |
| Client MCP config | Client-specific; see `client-targets.md` |
| Credentials | `~/.raven/.env` (mode 600) or OS-encrypted store via the credential script |
| Crow setup state | Crow Setup state directory (no secrets) |

## Security model to explain

- Credentials are read by the server at startup, never placed in the client
  config, never shown to the model, never logged.
- Personal-information scrubbing is optional (`RAVEN_SCRUB_PI=true`).
- Servers marked `pre-stable` in the catalog may change; say so.
- The setup flow previews every change and needs approval before applying it,
  and keeps a backup and rollback target.

## Check understanding

End with one question: "Which systems do you use day to day?" Use the answer
to propose the starter set.
