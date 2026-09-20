---
name: crow-project-context
description: Reads and safely maintains the public-reference project memory in a repository-root crow.config file, including Sonar settings and provider-neutral CI/CD, work-tracking, repository, and documentation references.
---

# Crow Project Context

Use this skill when an agent needs project-specific Sonar settings, CI/CD
references, work-tracking locations, related repositories, documentation
locations, or must record a resource supplied during the current task.

## Workflow

1. Read `crow.config` at the target repository root before searching external
   systems. If it is absent, continue with normal discovery and report that
   project memory was unavailable; do not create it unless the user requests
   configuration memory.
2. Treat the file as a public reference manifest. Resolve symbolic
   `connection_ref` and `resource_ref` values only when the calling agent
   declares the corresponding read-only MCP/Raven provider tool. Agents
   without that tool may use local and public descriptors, but must leave
   private references unresolved and report what provider lookup is needed;
   never guess an endpoint.
3. Keep credentials, provider base URLs, internal hostnames, provider response
   bodies, and absolute paths out of the committed file. Raven's protected
   per-user credential storage remains the source for credentials and service
   endpoints; Crow does not duplicate or manage those secrets.
4. When a user explicitly asks to remember or update a pipeline, board, ticket,
   repository, or documentation locator, verify it with the relevant read-only
   provider tool, then record only a safe public descriptor or a symbolic
   reference in `crow.config`. A locator supplied only for an immediate lookup
   is not authorization to mutate project memory; ask for confirmation when
   the user's intent is ambiguous.
   Store private locator values in Raven/provider storage or the user-local
   `~/.crow/crow.config.local` overlay. Never copy an internal URL into the
   repository, logs, reports, or tool arguments that are not required for the
   lookup.
5. Preserve existing entries and unknown fields. Record provenance with
   `discovered.source`, `discovered.recorded_by`, and `discovered.recorded_on`
   when adding a learned reference. If the safe descriptor cannot be derived,
   leave the resource unresolved and report the required private
   `resource_ref`; do not invent a value.
6. Stop on malformed configuration, conflicting resource identities, an
   attempted secret or internal-URL write, or a provider lookup that cannot be
   independently verified. Surface the failure instead of silently falling
   back to an unscoped endpoint.

## Security issue routing

Security workflows resolve the app's ticketing system from `work_tracking`.
An entry whose provider is `discover`, whose reference cannot be resolved, or
which conflicts with another candidate is unknown. Ask the user for the
provider and a safe project/board descriptor, then separately ask whether to
remember it. Do not treat a GitHub repository as the app's ticketing system
unless a GitHub `work_tracking` entry says so.

After a user selects security issue destinations, offer to remember the choice
with an optional public-safe section:

```yaml
security_issue_routing:
  destinations: [ghas, work_tracking]
  work_tracking_id: "primary"
  routes:
    - application_id: "api"
      service_path: "src/api"
      destinations: [ghas, work_tracking]
      work_tracking_id: "api-board"
```

`ghas` is valid only when `project.repository.provider` is `github`.
`work_tracking_id` must match an existing, verified `work_tracking` entry.
The top-level values are the single-app/default route. A multi-app repository
requires one route per inventoried app unless the user explicitly keeps an
app local-only. Store no issue payloads, internal URLs, credentials, or
provider responses.

## Raven-aligned secret boundary

Raven stores credentials outside the repository in protected, user-scoped
storage (DPAPI on Windows and the macOS login Keychain). Crow configuration
must refer to those connections by name, such as `raven:github` or
`raven:work-tracking`, and must not contain their values. The public manifest
is project memory, not a credential store.

## Completion gate

- `crow.config` was read or its absence was reported.
- Provider lookups used the configured connection and were read-only unless
  the calling workflow explicitly authorizes a mutation.
- Any learned reference is sanitized, provenance-marked, and safe for a public
  repository.
- A `crow.config` mutation was explicitly requested or confirmed by the user.
- No internal URL, secret, response body, absolute path, or token was written.
