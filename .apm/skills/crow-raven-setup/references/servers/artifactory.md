# Artifactory (`artifactory`)

Load only when the user selected Artifactory. Follow the pattern in
[../credentials-servers.md](../credentials-servers.md).

## What is different

The secret is the user's **IDIR password**, not a generated token. Say this
plainly before anything else: it is a real account password, it must never be
pasted into chat, email or a ticket, and Raven deliberately keeps it separate
from the Atlassian values. If the user is uncomfortable storing it, stop and
let them decide.

## Ask (one per turn)

1. The Artifactory base URL (`ARTIFACTORY_URL`). It is internal and HTTPS
   only. If the user does not know it, ask the Raven maintainer; never guess.
2. The account email (`ARTIFACTORY_EMAIL`), normally the `gov.bc.ca` address.

## Command

```
node setup-credentials-mac.mjs --raven-runtime <runtimePath> --sections artifactory --set ARTIFACTORY_URL=<url> --set ARTIFACTORY_EMAIL=<email>
```

The user types the IDIR password at the hidden prompt, then presses Enter once.

## Verify (read-only)

`artifactory_ping`, then `artifactory_list_repositories`.

## If it fails

- **401:** wrong password, or the IDIR password was recently changed. Re-run
  the command and re-enter it.
- **No response:** VPN may be required to reach the internal host.
- **Write tools** (upload, copy, move, delete) change shared artifacts:
  confirm with the user first.
