# GitHub (`github`)

Load only when the user selected GitHub. Follow the pattern in
[../credentials-servers.md](../credentials-servers.md).

## Ask (one per turn)

1. "Which repositories should Raven be allowed to touch?" This becomes
   `GITHUB_REPOSITORY_ALLOWLIST`, **required**: every GitHub tool refuses to
   run without it. Accept `owner/repo` or `owner/*`, comma-separated. Do not
   suggest a wildcard by default; recommend the smallest list. Echo it back.
2. "Is this github.com, or a GitHub Enterprise Server?" The default API URL is
   `https://api.github.com`. Set `GITHUB_API_URL` only for Enterprise.
3. "Do you want pull-request merge or code-scanning autofix tools enabled?"
   Both are off by default. Recommend leaving them off; enable only on an
   explicit yes (`GITHUB_ENABLE_MERGE=true`, `GITHUB_ENABLE_AUTOFIX=true`).
   Mutating tools still need `confirm: true` on each call.

## Token

Ask: "Do you already have a GitHub personal access token?" If not, one step
per turn:

1. Open GitHub, then Settings, **Developer settings**, **Personal access
   tokens**.
2. Create a token with an expiry and the narrowest scopes for the tools they
   will use: `security_events` for code-scanning tools; `repo`, or the
   fine-grained equivalents (issues, pull requests, contents, metadata) for
   issue and pull-request tools. A fine-grained token limited to the
   allow-listed repositories is better than a classic `repo` token.
3. If the organization enforces SAML SSO, authorize the token for it.
4. Copy it (shown once). Store it in a password manager and never share or
   paste it into chat.

## Command

```
node setup-credentials-mac.mjs --raven-runtime <runtimePath> --sections github --set GITHUB_REPOSITORY_ALLOWLIST=<list> [--set GITHUB_API_URL=<url>] [--set GITHUB_ENABLE_MERGE=true] [--set GITHUB_ENABLE_AUTOFIX=true]
```

## Verify (read-only)

`github_health`, then `repo_get_security_summary` for one allow-listed
repository.

## If it fails

- **"allowlist" error:** `GITHUB_REPOSITORY_ALLOWLIST` is missing or does not
  match the repository.
- **401:** token wrong or expired.
- **403 or "Resource not accessible":** scopes too narrow, or SAML SSO not
  authorized for the token.
