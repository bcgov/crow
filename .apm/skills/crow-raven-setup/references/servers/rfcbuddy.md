# RFC Buddy (`rfcbuddy`)

Load only when the user selected RFC Buddy. Follow the pattern in
[../credentials-servers.md](../credentials-servers.md).

## What is different

Raven documents the variables but not how a user obtains the PAT. Do not
invent steps. Ask whether they already have one; if not, send them to the
RFC Buddy owning team or the Raven maintainer.

## Ask (one per turn)

1. "Do you already have an RFC Buddy personal access token?" If not, stop and
   suggest the owning team.
2. The API base URL (`RFCBUDDY_URL`), for example
   `https://rfcbuddy.example.com/api/v1/`. Never guess the host; ask the
   owning team.

## Command

```
node setup-credentials-mac.mjs --raven-runtime <runtimePath> --sections rfcbuddy --set RFCBUDDY_URL=<url>
```

The user types the PAT at the hidden prompt. It is sent as a bearer token.

## Verify (read-only)

`rfcbuddy_search_rfcs` with a narrow query. Raven lists it as the server's one
tool; it only searches.

## If it fails

- **401 or 403:** PAT wrong or expired.
- **404:** the base URL path is wrong; check the `/api/v1/` suffix.
- **No response:** VPN may be required.
