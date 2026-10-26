# Server Monitor and IMIS (`server-monitor`)

Load only when the user selected Server Monitor or IMIS SSH tools. Follow the
pattern in [../credentials-servers.md](../credentials-servers.md).

## What is different

There is nothing to look up in a web console. The secret is the user's `_A`
account password. It is used for SSH password authentication and for `sudo` on
the remote server, so it is a real account password: never pasted into chat,
never shared. Key-based SSH is possible per host, but most workflows still
need `sudo`, so plan to keep the password set.

## Ask (one per turn)

1. "Do you have VPN access, and a `~/bin/servers.conf`?" Server Monitor needs
   both. If `servers.conf` is missing, point to Raven's README section 4a and
   Raven's `servers.conf.example`; creating it is a separate step from
   credentials.
2. Only the IMIS discovery tools (search, get, stats) work without VPN or the
   password; they read a local CSV. Mention it so the user knows what they
   can skip.

## Command

```
node setup-credentials-mac.mjs --raven-runtime <runtimePath> --sections server-monitor
```

There are no non-secret values. The user types the password at the hidden
prompt, then presses Enter once.

## Verify (read-only)

`server_dashboard`. All Server Monitor and IMIS operations are read-only by
design.

## If it fails

- **"No servers configured":** `servers.conf` is missing or empty.
- **Connection timeouts:** connect to the VPN.
- **Host key errors:** the host is not in `~/.ssh/known_hosts`. Raven checks
  host keys and fails with an actionable message; the user adds the key
  deliberately and does not turn verification off.
