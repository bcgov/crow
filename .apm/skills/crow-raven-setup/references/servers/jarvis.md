# Jarvis (`jarvis`)

Load only when the user selected Jarvis. Follow the pattern in
[../credentials-servers.md](../credentials-servers.md).

## What is different

Raven documents the variables but not how a user obtains a Jarvis token. Do
not invent steps. Ask the user whether they already have one; if not, send
them to the Jarvis owning team or the Raven maintainer.

## Ask (one per turn)

1. "Do you already have a Jarvis authorization token?" If not, stop and
   suggest the owning team; come back when they have it.
2. The Jarvis base URL (`JARVIS_BASE_URL`), required whenever a token is set,
   for example `https://jarvis-api.example.gov.bc.ca`. `/mcp` is appended
   automatically if omitted. Never guess the host.

## Command

```
node setup-credentials-mac.mjs --raven-runtime <runtimePath> --sections jarvis --set JARVIS_BASE_URL=<url>
```

The user types the token at the hidden prompt.

## Verify (read-only)

`list_ministries`, then `search_applications` with a small `limit`. The tool
list is whatever the remote advertises at runtime, so it may differ from the
catalog.

## If it fails

- **401 or 403:** token wrong, expired or not authorized.
- **No tools appear:** the base URL is wrong or the service is unreachable;
  VPN may be required.
- `update_application` writes to the inventory: confirm first.
