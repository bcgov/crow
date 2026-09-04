---
name: crow-application-development
description: Implement and evolve applications with technology-routed engineering practices. Use when writing production code, tests, configuration, integrations, persistence code, containers, or CI; includes current .NET and ASP.NET Core secure-by-default guidance.
---

# Application Development

Use this skill while implementing or changing an application. Data architecture and data modelling are out of scope; safe persistence implementation is included.

## Context-efficient loading

1. Inspect manifests and the affected entry point to identify the technology and workload.
2. Load [`modules/foundation.md`](modules/foundation.md) for every change.
3. Load [`modules/unicode-and-utf8.md`](modules/unicode-and-utf8.md) whenever the change reads, writes, validates, compares, searches, serializes, stores, exports, imports, or renders text.
4. Load [`../crow-application-architecture/modules/minimal-change.md`](../crow-application-architecture/modules/minimal-change.md) when choosing an abstraction, dependency, platform feature, or custom implementation.
5. Load [`../crow-application-architecture/modules/impact-analysis.md`](../crow-application-architecture/modules/impact-analysis.md) for bug fixes or changes to shared behavior, routes, events, or public contracts.
6. For .NET, load [`modules/dotnet/foundation.md`](modules/dotnet/foundation.md).
7. Add only the modules required by the task:
   - [`modules/dotnet/aspnet-core.md`](modules/dotnet/aspnet-core.md) for HTTP, MVC, Razor, Blazor, API, auth, middleware, or hosted SPA work.
   - [`modules/dotnet/persistence.md`](modules/dotnet/persistence.md) for EF Core, Dapper, SQL, migrations, or transactions.
   - [`modules/dotnet/testing-ci.md`](modules/dotnet/testing-ci.md) for tests, packages, builds, containers, or pipelines.
8. When the change consumes or provides a shared capability, canonical register, public service, or integration adapter, also load [`../crow-application-architecture/modules/platform-alignment.md`](../crow-application-architecture/modules/platform-alignment.md).
9. When the change crosses an identity, device, resource, transaction, privileged, workload, network, API, external-decision, or service trust boundary, also load [`../crow-application-architecture/modules/zero-trust.md`](../crow-application-architecture/modules/zero-trust.md).
10. Add future technologies as sibling folders under `modules/` and update this router. Never load unrelated technology modules.

## Implementation loop

1. Read the affected behavior, tests, configuration, and composition root before editing.
2. Apply the minimal-change decision ladder; record a `crow-debt:` marker when a deliberate ceiling is accepted.
3. For a bug or shared behavior change, complete bounded impact analysis and verify callers, contracts, and tests before editing.
4. Reuse existing abstractions and conventions; add a new abstraction only when it owns policy or isolates a real boundary.
5. Implement validation, authorization, failure behavior, cancellation, telemetry, and secure configuration with the feature.
6. For a routed Zero Trust boundary, enforce the decision at the resource/action boundary, use the smallest scope and lifetime, and define expiry, revocation, exception, and dependency-failure behavior.
7. Add or update the smallest sufficient focused check for non-trivial logic, plus broader tests when a real boundary or risk requires them.
8. For text-bearing changes, test representative Indigenous-language and multilingual values across the complete affected round trip.
9. Run the repository's existing formatter/linter first, then the smallest relevant tests, then build/package checks.
10. Run the repository's established security and quality scans. Do not weaken gates to make the change pass.

For routed platform boundaries, confirm shared-service reuse before adding a
new capability; identify the contract owner and version/compatibility policy;
request only the minimum disclosed data for the stated subject and purpose;
propagate timeout, retry, idempotency, cancellation, and retry-exhaustion
behavior; define a safe, visible fallback; and plan migration and rollback.

## Security integration

Load the relevant `../crow-security-review/modules/` files before implementing the affected surface:

- endpoint or permission change: `auth-and-access-control.md`;
- ASP.NET Core bootstrap/configuration: `framework-security-config.md`;
- API, cookie, token, CORS, antiforgery, or rate limit: `api-and-session-security.md`;
- SQL, file, process, redirect, or outbound URL: `data-flow-sinks.md`;
- secrets or deployment configuration: `secrets-and-credentials.md`;
- crypto, keys, certificates, or TLS: `crypto-and-transport.md`;
- external deserialization, webhooks, or artifact integrity: `deserialization-and-integrity.md`;
- SPA/client work: `frontend-spa-security.md`.

Apply these as definition-of-done criteria. Run a security review after implementation as verification, not as the first time security is considered.
