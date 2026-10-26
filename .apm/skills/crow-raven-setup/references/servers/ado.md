# Azure DevOps (`ado`)

Load only when the user selected Azure DevOps. Follow the pattern in
[../credentials-servers.md](../credentials-servers.md): collect non-secrets in
chat, guide the PAT one step per turn, secret at the hidden prompt only.

## Ask (one per turn)

1. "Is this Azure DevOps Services (cloud, `dev.azure.com`) or an on-premises
   Azure DevOps Server / TFS?"
2. **Cloud:** ask for the organization name. Set
   `ADO_BASE_URL=https://dev.azure.com` and put the organization only in
   `ADO_DEFAULT_COLLECTION`. Putting it in both duplicates the path and breaks
   calls. Echo both values back.
3. **Server:** ask for the HTTPS base URL and the collection (often
   `DefaultCollection`). Optionally set `ADO_API_VERSION`: default 7.1,
   Server 2020 is 6.0, Server 2019 is 5.0.
4. Optional: the default project name (`ADO_DEFAULT_PROJECT`).

Cloud is external to BC Gov infrastructure. Say once that a privacy and
data-residency review comes before using it with enterprise data.

## Token

Ask: "Do you already have an Azure DevOps personal access token?" If not,
offer a walkthrough, one step per turn:

1. Open Azure DevOps and click the user-settings icon, then **Personal access
   tokens**.
2. **New Token**. Name it (for example `raven-mcp`), pick the organization,
   and set a short expiry.
3. Choose the narrowest scopes for what they will do. Read-only work needs
   read scopes for Work Items, Code, Build and Project. Add write scopes only
   if they will create work items, comments or pull requests.
4. **Create**, then copy. It is shown once. Store it in a password manager and
   never share or paste it into chat.

## Command

```
node setup-credentials-mac.mjs --raven-runtime <runtimePath> --sections ado --set ADO_BASE_URL=<url> --set ADO_DEFAULT_COLLECTION=<org or collection> [--set ADO_DEFAULT_PROJECT=<project>]
```

## Verify (read-only)

`list_projects`. Cloud needs `ADO_DEFAULT_COLLECTION` set for this call.

## If it fails

- **401 or 403:** token expired, wrong organization, or scopes too narrow.
  Recreate with the needed scopes.
- **404 or a doubled path:** the organization is in both `ADO_BASE_URL` and
  `ADO_DEFAULT_COLLECTION`. Keep the base URL at the host root.
- `list_release_pipelines` supports Server only; on Cloud it reports an error
  rather than switching hosts. That is expected.
