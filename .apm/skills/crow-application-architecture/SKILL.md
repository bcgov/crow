---
name: crow-application-architecture
description: Design or review application architecture using technology-routed guidance. Use for new application boundaries, project structure, dependency direction, deployment shape, and cross-cutting concerns; includes current .NET and ASP.NET Core guidance.
---

# Application Architecture

Use this skill when designing a new application or making a structural change to an existing one. Data architecture, database topology, and domain data modelling are intentionally out of scope.

## Context-efficient loading

1. Inspect only the repository manifests and entry points needed to identify the application type.
2. Load [`modules/principles.md`](modules/principles.md) for every application.
3. Load [`modules/unicode-and-utf8.md`](modules/unicode-and-utf8.md) for every application.
4. Load [`modules/dotnet.md`](modules/dotnet.md) only when a solution contains `.sln`, `.slnx`, `.csproj`, `.vbproj`,`.fsproj`, or `global.json`.
5. Load [`modules/aspnet-core.md`](modules/aspnet-core.md) only for ASP.NET Core web, API, Razor, Blazor, or hosted SPA projects.
6. Load [`modules/platform-alignment.md`](modules/platform-alignment.md) only when the application provides or consumes a shared capability, canonical register, public service, integration adapter, or other one-to-many dependency.
7. Load [`modules/zero-trust.md`](modules/zero-trust.md) only when the application has a meaningful identity, device, workload, resource, transaction, privileged, network, API, external-decision, or cross-service trust boundary.
8. For another technology, add a sibling module and route to it here. Do not expand the default context with unrelated stacks.

If the application uses multiple technologies, load only the modules for components affected by the current decision.

## Workflow

1. Establish the application type, trust boundaries, deployment unit, expected scale, availability needs, and integration points.
2. Select the smallest architecture that satisfies those constraints.
3. Define project/module boundaries and dependency direction before choosing implementation libraries.
4. Place authentication, authorization, validation, observability, resiliency, and operational health in the design rather than deferring them to remediation.
5. Record important decisions and rejected alternatives in the repository's established ADR format.
6. Verify end-to-end Unicode/UTF-8 readiness across input, storage, processing, search, integration, export, and rendering boundaries.
7. Verify the proposed structure against the relevant technology module and existing deployment constraints.
8. When the platform-alignment module is routed, record the conditional role classification, one-to-many impact, reuse decision, data custodian and sharing spectrum, narrow-question API choice, contract owner/versioning, and dependency degradation behavior with evidence and confidence.
9. When the Zero Trust module is routed, inventory protected resources and access paths, identify enforcement points, define least-privilege scope and duration, specify revocation and degradation behavior, document time-bound exceptions, and record only evidence-supported measures.

## Security integration

Security is an architectural input. For .NET web applications, load only the relevant modules from `../crow-security-review/modules/`:

- Always consider `auth-and-access-control.md`, `framework-security-config.md`, and `secrets-and-credentials.md`.
- Add `api-and-session-security.md` for HTTP APIs, browser sessions, cookies, CORS, JWT, or rate limiting.
- Add `data-flow-sinks.md` when untrusted input can reach SQL, files, commands, redirects, or outbound HTTP.
- Add `crypto-and-transport.md` for cryptography, keys, certificates, or custom transport configuration.
- Add `deserialization-and-integrity.md` for external payloads, webhooks, artifact integrity, or polymorphic serialization.
- Add `frontend-spa-security.md` only when a SPA is present.

Treat these modules as design acceptance criteria, not a post-build checklist.
