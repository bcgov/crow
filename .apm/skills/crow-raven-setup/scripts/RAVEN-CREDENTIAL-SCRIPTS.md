# Raven credential scripts (copied)

These files are unmodified copies from https://github.com/bcgov/raven
(`scripts/`), revision `84338695956cf4053ed436412ae22e7ace74268b`. They ship in
this skill so the credentials step works without a Raven clone.

| File | Platform | SHA-256 |
|---|---|---|
| `setup-credentials-mac.mjs` | macOS (login keychain) | `7b8553ae53f936c540d40879840595669a3a2b785d13ebcce76aeac1f8be7163` |
| `setup-credentials-mac.lib.mjs` | imported by the macOS script | `adf567228fb1ae77ea587f5fb7f37d4b9bb191c94832bfb08bcdab3f5c7dc5f4` |
| `setup-credentials.ps1` | Windows (DPAPI) | `6e7e4ea911449e5e29ba97b3af52669f6941f34018d773136e8fa0b569881440` |

Do not edit these files here. Fix defects in Raven, then re-copy and update the
revision and digests above. When the installed Raven runtime has a newer
`scripts/` copy, prefer a re-sync over local changes.
