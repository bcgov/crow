# Jenkins (`jenkins`)

Load only when the user selected Jenkins. Follow the pattern in
[../credentials-servers.md](../credentials-servers.md).

## Decide the auth path first

Raven supports two. Ask: "Does your Jenkins accept a username and API token,
or is it behind the BC Gov login (SiteMinder)?"

- **API token (preferred, works for autonomous use):** continue below.
- **Behind SiteMinder:** Basic auth can never succeed there, because the login
  intercepts the request before Jenkins sees the credentials. Raven then
  switches to a cached SMSESSION browser login, which may open a browser.
  Skip this guide's command and tell the user plainly; ask the Jenkins owner
  for a host that accepts Basic auth instead.

## Ask (one per turn)

1. The Jenkins HTTPS base URL (`JENKINS_URL`). HTTP is rejected. Keep any path
   such as `/jenkins`.
2. The Jenkins username (`JENKINS_USER`).

## Token

Ask: "Do you already have a Jenkins API token?" If not:

1. Sign in to Jenkins, click your name (top right), then **Configure**.
2. Under **API Token**, click **Add new Token** and name it
   (`raven-mcp`).
3. **Generate**, then copy. It is shown once. Store it in a password manager
   and never share or paste it into chat.

Prefer the API token over the account password; it is the recommended write
credential.

## Command

```
node setup-credentials-mac.mjs --raven-runtime <runtimePath> --sections jenkins --set JENKINS_URL=<url> --set JENKINS_USER=<username>
```

Two secret prompts appear: type the token at **Jenkins API token**, then press
Enter at **Jenkins password** to leave it empty.

## Verify (read-only)

`get_controller_info`, then `list_jobs`.

## If it fails

- **401 or 403 straight from the controller:** returned directly, with no
  browser fallback. Wrong user, wrong token, or the user lacks permission.
- **Browser login opens unexpectedly:** the URL is SiteMinder-protected.
  See the decision above.
- **Write tools:** confirm with the user before any write call. Job config
  updates need the current SHA-256 and exact XML.
