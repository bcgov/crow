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
4. For .NET, load [`modules/dotnet/foundation.md`](modules/dotnet/foundation.md).
5. Add only the modules required by the task:
   - [`modules/dotnet/aspnet-core.md`](modules/dotnet/aspnet-core.md) for HTTP, MVC, Razor, Blazor, API, auth, middleware, or hosted SPA work.
   - [`modules/dotnet/persistence.md`](modules/dotnet/persistence.md) for EF Core, Dapper, SQL, migrations, or transactions.
   - [`modules/dotnet/testing-ci.md`](modules/dotnet/testing-ci.md) for tests, packages, builds, containers, or pipelines.
6. When the change consumes or provides a shared capability, canonical register, public service, or integration adapter, also load [`../crow-application-architecture/modules/platform-alignment.md`](../crow-application-architecture/modules/platform-alignment.md).
7. Add future technologies as sibling folders under `modules/` and update this router. Never load unrelated technology modules.

## Implementation loop

1. Read the affected behavior, tests, configuration, and composition root before editing.
2. Reuse existing abstractions and conventions; add a new abstraction only when it owns policy or isolates a real boundary.
3. Implement validation, authorization, failure behavior, cancellation, telemetry, and secure configuration with the feature.
4. Add or update focused tests for success, denial, invalid input, and material failure paths.
5. For text-bearing changes, test representative Indigenous-language and multilingual values across the complete affected round trip.
6. Run the repository's existing formatter/linter first, then the smallest relevant tests, then build/package checks.
7. Run the repository's established security and quality scans. Do not weaken gates to make the change pass.

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
