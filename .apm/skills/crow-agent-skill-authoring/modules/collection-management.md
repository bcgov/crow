# Collection Compatibility

Crow's curated subsets are retired from v0.19.0. Retain exactly these
compatibility-only addresses indefinitely:

| Directory / selector suffix | Package name |
|---|---|
| `collections/starter-package` | `bcgov-crow-starter-package` |
| `collections/security-remediation` | `bcgov-crow-security-remediation` |

## Wrapper contract

- Each directory contains only `apm.yml` and `README.md`, with no own assets,
  publication subsets, or copied source.
- Each manifest has exactly one APM dependency: explicit
  `git: https://github.com/bcgov/crow.git`, `ref: v<version>`, and **no path**.
  This resolves the full same-repository root package, not a parent-directory
  traversal or `.apm/` virtual asset. Do not use `..`.
- Keep wrapper versions and dependency refs aligned with the root package
  and plugin. The root declares `dependencies: {}`; it must not depend back
  on a wrapper and form a cycle.
- Recommend `bcgov/crow#stable` for new installations. Legacy selectors and
  package names remain valid; do not claim APM rewrites a user's selector.
- While any legacy selector remains, use **two native APM update passes**
  after confirmation: the first refreshes wrapper metadata; the second
  rediscovers its full-root dependency graph. Verify complete content and
  removal of obsolete per-asset lock entries after pass two. A first-pass
  wrapper refresh is not migration success. Immutable
  tags and archives retain their original content and require an explicit
  version/ref change.
- No security remediation capability is removed by retiring its subset.
  Use the [canonical version policy](../../crow-release/modules/versioning.md)
  to classify the entire release.
- Uninstalling the direct full package removes all installed Crow package
  content, including content still named by legacy aliases. Do not promise
  alias-backed copies will remain. Preserve unrelated human-owned files; do
  not extend package uninstall to Raven runtimes, credentials, or MCP client
  configuration. Legacy selector entries are not automatically rewritten.

## Change and validation gates

1. Update both wrapper manifests and READMEs together with root/plugin version
   changes. Do not add a new curated subset or remove a retained address.
2. Run `scripts/Test-CrowCollectionCompatibility.Tests.ps1` and
   `scripts/Test-CrowAssetDependencyGraph.Tests.ps1`, then the asset validator.
   Its shared parser checks the strict two-wrapper contract; the dependency
   graph represents each wrapper's root edge and full publication closure.
   Generic synthetic subset fixtures remain tests of graph traversal only.
3. Keep discovery documentation consistent and confirm evidence is not
   tracked or packaged. The one-time collection migration was validated
   during development; it does not require revalidation for each release.
