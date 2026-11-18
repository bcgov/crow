# Crow Security Remediation — compatibility address

The curated Security Remediation subset is retired. Its exact selector
`bcgov/crow/collections/security-remediation` and package name
`bcgov-crow-security-remediation` are retained indefinitely as a
compatibility-only address. From v0.19.0, this wrapper depends on the complete
Crow root package at the matching release tag; it owns no agents or skills.
The security review and remediation agents and skills are not removed.

For new installs, use the canonical package:

```powershell
apm install bcgov/crow#stable --global --target copilot
```

For existing installs on a mutable ref such as `#stable`, run **two native
update passes** after confirmation when that ref advances to this release:

```powershell
apm update --global --target copilot
apm update --global --target copilot
```

The first pass refreshes this wrapper; the second resolves its complete
root dependency graph. Verify complete content after the second pass.
Continue using two passes while any legacy selector remains.
APM retains the user's legacy selector; it does not automatically rewrite it
to `bcgov/crow`.

Uninstalling the direct full package removes all installed Crow package
content, including content needed by this alias. Alias-backed copies are not
preserved; unrelated human-owned files must remain untouched. Package
uninstall does not automatically remove Raven or MCP client configuration.

Exact tags and downloaded archives remain pinned to their original content.
Updating an immutable install requires an explicit version/ref change. This
release's retained address is:

```powershell
apm install bcgov/crow/collections/security-remediation#v0.20.1 --global --target copilot
```

Use the [root package documentation](../../README.md) for discovery and setup.
The [Crow Security Remediation Agent](../../.apm/agents/crow-security-remediation.agent.md)
keeps external issue publication and ticket updates confirmation-gated.
See the [collection compatibility rules](../../.apm/skills/crow-agent-skill-authoring/modules/collection-management.md)
for the wrapper contract.
