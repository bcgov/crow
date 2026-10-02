# REST and SOAP API inventory

Load when the classified application or service exposes a REST or SOAP API.
The inventory is a source-backed description of the API surface, not an
assertion that every behavior or consumer has been discovered.

## Discovery boundary

Inspect repository-local route/controller/handler definitions, WSDL and XSD,
OpenAPI/Swagger documents, generated clients and service stubs, tests, deployment
configuration, and existing API documentation. Reconcile declarations with
implementation where both exist. Do not probe production or send state-changing
requests. Any runtime check requires an explicitly approved non-production
target; a successful probe alone does not establish inventory completeness.

For every operation, capture:

- a stable `OP-###` identifier and owning `API-###` identifier;
- protocol, API version, HTTP method and route/service path;
- request media types and documented success and error response cases;
- for SOAP, SOAP version, action, request/response elements, and faults;
- read-only, state-mutating, or unknown side-effect classification;
- evidence references, confidence, ownership, consumers, authentication, and
  unresolved questions.

Inventory each distinct REST method/path and each SOAP operation, even when
several SOAP operations share one HTTP service endpoint. Keep source evidence
repository-relative and line-addressable. Do not put credentials, captured
payloads, authorization headers, cookies, or production data in this artifact.

## Completeness and confidence

Set top-level `completeness` to:

- `Verified` only after reconciling all applicable route, contract, and
  service-definition sources for the bounded application/service. Record
  evidence for that reconciliation.
- `Partial` when a known source or service boundary remains uninspected.
- `Unknown` when the operation boundary cannot be established.

An unresolved question that could hide an operation must set
`blocksCompleteness` to `true`. A complete inventory can still have unknown
owners or operation details; it cannot support a 100% scenario-coverage claim
while the operation boundary is partial or unknown. `Verified` completeness is
an evidence-backed reviewer judgment, not something the JSON validator can
prove.

## Output and validation

Write `api-inventory.json` beside the architecture document, starting from
[`../resources/api-inventory-template.json`](../resources/api-inventory-template.json).
Use `EV-###` IDs for source evidence and `RC-###` IDs for each distinct success
or error response case. Response case IDs are unique across the inventory and
allow a modernization harness to prove that every documented case was run.
Use `Unknown` only when evidence is genuinely absent; never invent route,
response, version, ownership, or fault details.

The inventory's `sourceRevision` must identify the inspected Git revision and
`generatedAt` must be an ISO-8601 UTC timestamp ending in `Z`. A monorepo
inventory's `scope` must match its architecture service. The
`Test-ArchitectureOutput.ps1` validator validates this sidecar when present and
requires it for single-app `-RequireApiInventory` or monorepo services marked
`apiInventoryRequired: true`.
