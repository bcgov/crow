# Credentials per server

Load after `credentials.md` for any selected server that needs authentication.
Every guide follows the same pattern:

1. Ask for the non-secret values in chat, one short question at a time.
2. Offer a walkthrough for creating the secret, one step per turn.
3. Give one command: `--sections <id>` plus a `--set KEY=VALUE` for each
   non-secret value. The user types only the secret at the hidden prompt.
4. Restart the client, then verify with the read-only call.

Never ask for a secret in chat. Variable names and scopes come from Raven's
README; if a value is unknown, send the user to the owning team or the Raven
maintainer and never guess a host.

Load only the guide for each selected server.

| Server | Guide | `--sections` | Secret (hidden prompt) | Verify (read-only) |
|---|---|---|---|---|
| Jira and Confluence | [atlassian.md](servers/atlassian.md) | `atlassian` | Atlassian API token (Classic) | Jira `read_issue`, Confluence `list_spaces` |
| Azure DevOps | [ado.md](servers/ado.md) | `ado` | `ADO_PAT` | `list_projects` |
| SonarQube | [sonar.md](servers/sonar.md) | `sonar` | `SONARQUBE_TOKEN` | `sonar_list_projects` |
| Jenkins | [jenkins.md](servers/jenkins.md) | `jenkins` | `JENKINS_TOKEN` (Enter at `JENKINS_PASSWORD`) | `get_controller_info`, `list_jobs` |
| GitHub | [github.md](servers/github.md) | `github` | `GITHUB_TOKEN` | `github_health`, `repo_get_security_summary` |
| Artifactory | [artifactory.md](servers/artifactory.md) | `artifactory` | `ARTIFACTORY_PASSWORD` (IDIR password) | `artifactory_ping`, `artifactory_list_repositories` |
| Jarvis | [jarvis.md](servers/jarvis.md) | `jarvis` | `JARVIS_TOKEN` | `list_ministries` |
| RFC Buddy | [rfcbuddy.md](servers/rfcbuddy.md) | `rfcbuddy` | `RFCBUDDY_PAT` | `rfcbuddy_search_rfcs` |
| Server Monitor / IMIS SSH | [server-monitor.md](servers/server-monitor.md) | `server-monitor` | `SERVER_A_PASSWORD` | `server_dashboard` (needs VPN) |

Combine sections in one run, for example `--sections ado,sonar`. Skip the
walkthrough for a server only when the user says they already have the
credential.

## After entry

1. Restart the client so the servers reload; they read credentials once at
   startup, so a running server keeps old values.
2. Run the read-only verify call from the table.
3. Report installed, configured and verified per server. A server whose verify
   call fails is configured but not verified; use `verify-and-troubleshoot.md`.
