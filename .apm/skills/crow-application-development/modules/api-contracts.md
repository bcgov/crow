# REST and SOAP API implementation

Load for a new REST or SOAP API, a change to an existing API contract, or a
rewrite/port between protocols or technology stacks. Keep implementation
guidance protocol-neutral here; route framework and language details only after
detecting the target technology and following the existing project conventions.

## Establish the contract before implementation

- Inventory existing operations from source and OpenAPI/WSDL/XSD, identify
  owners and consumers, and distinguish a verified contract from inferred or
  undocumented behavior. For modernization, reuse
  [`../crow-architecture-review/modules/api-inventory.md`](../../crow-architecture-review/modules/api-inventory.md).
- Confirm the intended compatibility boundary: operation names, routes and
  methods, request/response schemas, media types, status/fault behavior,
  authentication/authorization, validation, idempotency, and side effects.
- Ask before changing ambiguous or undocumented behavior. Do not silently
  repair legacy quirks during a rewrite; document each approved divergence.
- For cross-protocol rewrites, map equivalent business outcomes rather than
  translating wire formats mechanically. Preserve SOAP actions, namespaces,
  schema constraints and faults where applicable; preserve REST method,
  resource, status, content-negotiation and error semantics where applicable.

## Implement and verify

- Keep the contract and implementation aligned; update the authoritative
  OpenAPI or WSDL/XSD source and generated artifacts using the repository's
  established tooling.
- Validate input at the server boundary, authorize each protected operation
  and resource, and define safe error mapping without disclosing stack traces,
  internal hostnames, secrets, or sensitive values.
- Bound request size, timeouts, retries, concurrency and resource use. Define
  cancellation and idempotency behavior before retrying any state-changing
  request.
- Use safe XML and JSON parsers, enforce schema/size limits, and do not enable
  unsafe object deserialization or external-entity resolution.
- Preserve or intentionally version changes to operation behavior. Define
  deprecation, consumer migration, rollback, and compatibility policy with the
  contract owner.
- For API modernization, follow the approved scenarios in
  [`../crow-testing/modules/reference/api-modernization-harness.md`](../../crow-testing/modules/reference/api-modernization-harness.md)
  and compare both deployed implementations over HTTP. Load the relevant
  `crow-testing` integration and security-boundary guidance as well.

## Security routing

Apply the skill's security integration routes for endpoint authorization,
framework configuration, API/session controls, untrusted deserialization,
data-flow sinks, secrets, and transport. A generated OpenAPI/WSDL document or
passing schema test does not prove authorization, runtime behavior, or
consumer compatibility.
