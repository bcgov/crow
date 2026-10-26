# SonarQube (`sonar`)

Load only when the user selected SonarQube. Follow the pattern in
[../credentials-servers.md](../credentials-servers.md).

## Ask (one per turn)

1. "Which SonarQube do you use: SonarQube Cloud, or an internal SonarQube
   Server?"
2. **Cloud:** `https://sonarcloud.io` (EU) or `https://sonarqube.us` (US).
   Neither is Canadian: say once that a privacy and data-residency review
   comes first. Also ask for the Sonar **organization key**; tool calls need
   it, but it is not a credential, so just note it for later.
3. **Server:** ask for its HTTPS base URL, which may end in `/sonar`. HTTPS is
   required.
4. Only if they will run local scans: the `sonar-scanner` path
   (`SONAR_SCANNER_BIN`), and only when it is not on `PATH`.

## Token

Ask: "Do you already have a SonarQube user token?" If not, walk through one
step per turn:

1. Sign in to SonarQube, open the account menu, then **My Account**, then
   **Security**.
2. Under **Generate Tokens**, name it (for example `raven-mcp`), choose type
   **User Token**, and an expiry.
3. **Generate**, then copy. It is shown once. Store it in a password manager
   and never share or paste it into chat.

## Command

```
node setup-credentials-mac.mjs --raven-runtime <runtimePath> --sections sonar --set SONARQUBE_URL=<url> [--set SONAR_SCANNER_BIN=<path>]
```

## Verify (read-only)

`sonar_list_projects`. On Cloud, pass the `organization` argument. Server
needs no organization.

## If it fails

- **401:** token wrong, expired or revoked. Generate a new user token.
- **Empty list on Cloud:** the `organization` argument is missing or wrong.
- **Scans on US Cloud:** pass `-Dsonar.region=us` in `extraArgs`; the scanner
  defaults to EU.
- **.NET scans:** use `/o:<key>` in `extraArgs`, not `sonar.organization`.
