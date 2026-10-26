# Raven credential scripts (Crow copies)

Copied from https://github.com/bcgov/raven (`scripts/`), revision
`84338695956cf4053ed436412ae22e7ace74268b`, then modified by Crow. They need an
installed Raven runtime; pass it with `--raven-runtime`.

| File | Platform | Status |
|---|---|---|
| `setup-credentials-mac.mjs` | macOS (login keychain) | **Modified**: adds `--set KEY=VALUE` (non-secret fields only), `--sections`, `--raven-runtime`; stored non-secret values are not re-asked in `--sections` mode; Server Monitor split into its own section; Atlassian token prompt relabelled |
| `setup-credentials-mac.lib.mjs` | imported by the macOS script | Logic unmodified; Crow added a conventions header and a doc comment on `applyAnswer`. Original SHA-256 `adf567228fb1ae77ea587f5fb7f37d4b9bb191c94832bfb08bcdab3f5c7dc5f4`; current `09a79f21697618a14f5c9db89c093383af58cb578b1607129f154c4945365115` |
| `setup-credentials.ps1` | Windows (DPAPI) | Logic unmodified, interactive only; Crow added a comment-based help header and function comments. Original SHA-256 `6e7e4ea911449e5e29ba97b3af52669f6941f34018d773136e8fa0b569881440`; current `e0bdc95d62efe61009aebe1a4c28e78856110e8e4272f0032f5cc1607f3404fe` |

Crow edits to these copies are limited to the coding-conventions headers and
comments above, plus the macOS script's additions. Do not change their logic
here. Fix defects in Raven, then re-copy, re-apply the headers, and update the
revision and digests above. When the installed Raven runtime has a newer
`scripts/` copy, prefer a re-sync over local changes.
