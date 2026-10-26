# Raven credential scripts (Crow copies)

Copied from https://github.com/bcgov/raven (`scripts/`), revision
`84338695956cf4053ed436412ae22e7ace74268b`, then modified by Crow. They need an
installed Raven runtime; pass it with `--raven-runtime`.

| File | Platform | Status |
|---|---|---|
| `setup-credentials-mac.mjs` | macOS (login keychain) | **Modified**: adds `--set KEY=VALUE` (non-secret fields only), `--sections`, `--raven-runtime`; stored non-secret values are not re-asked in `--sections` mode; Server Monitor split into its own section; Atlassian token prompt relabelled |
| `setup-credentials-mac.lib.mjs` | imported by the macOS script | Unmodified. SHA-256 `adf567228fb1ae77ea587f5fb7f37d4b9bb191c94832bfb08bcdab3f5c7dc5f4` |
| `setup-credentials.ps1` | Windows (DPAPI) | Unmodified, interactive only. SHA-256 `6e7e4ea911449e5e29ba97b3af52669f6941f34018d773136e8fa0b569881440` |

Do not edit these files here. Fix defects in Raven, then re-copy and update the
revision and digests above. When the installed Raven runtime has a newer
`scripts/` copy, prefer a re-sync over local changes.
