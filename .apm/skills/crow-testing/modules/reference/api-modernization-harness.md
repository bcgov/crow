# REST/SOAP API characterization and modernization harness

Load for an existing HTTP API being characterized, rewritten, ported, or
compared with a replacement. This is API integration testing, not browser E2E.
Use the owning test framework and HTTP client; this module defines the
protocol-neutral inventory, scenario, safety, and completion contract.

## Preconditions and scenarios

1. Load the service's validated
   [`API inventory`](../../../crow-architecture-review/modules/api-inventory.md).
   Stop if the operation boundary is partial/unknown, evidence is stale, or an
   operation's route, side effects, or success/error response cases needed for
   testing are unknown. A verified inventory is a reviewer judgment backed by
   source evidence, not proof that no undocumented behavior exists.
2. Create and obtain explicit user/owner approval for the API scenario document
   before writing test code. Cover every inventoried operation and every
   distinct `RC-###` success and error response case with at least one scenario.
   Add further cases where authorization, validation, content negotiation,
   SOAP faults, idempotency, or state transitions create distinct behavior.
3. Give each scenario a stable `SCN-###` ID, operation ID, response-case ID,
   kind (`success` or `error`), expected semantic result, test reference, and
   any required mutation-safety evidence. Do not infer expected behavior from a
   response observed only once; use the approved contract, verified baseline,
   or an explicit owner decision.

## Execute both sides over HTTP

- Run the same approved scenario set against the legacy baseline and modernized
  candidate using real HTTP requests. Do not substitute controller invocation,
  an in-process handler call, or a mock for the cross-version HTTP comparison.
  A local host is acceptable when it is reached through its bound HTTP
  endpoint.
- Supply target base addresses through distinct uppercase environment-variable
  references matching `^[A-Z_][A-Z0-9_]*$`; keep actual addresses,
  credentials, tokens, cookies, authorization headers, request/response
  bodies, and production traffic out of manifests and result reports.
- Use approved non-production targets only. Before any state-mutating request,
  confirm an isolated dataset/tenant, explicit scenario approval, unique test
  data, and reliable cleanup or reset. Do not replay production writes or
  silently assume a request is safe because it is idempotent.
- For REST-to-REST or SOAP-to-SOAP, keep operation-specific wire assertions
  where they are contractually relevant. For SOAP-to-REST, use separate
  protocol adapters and compare business meaning: inputs, outcomes, errors,
  state effects, authorization, and required metadata. Do not compare XML and
  JSON bytes, SOAP actions and REST routes, or transport status codes as if
  those were interchangeable.
- Keep normalization explicit, narrow, and reviewed. Every non-equivalent
  result requires a recorded decision reference; unresolved differences fail
  the gate.

## Coverage manifest and deterministic gate

Start from:

- [`api-scenario-manifest-template.json`](../../templates/api-scenario-manifest-template.json)
- [`api-run-results-template.json`](../../templates/api-run-results-template.json)

The approved test suite must emit a sanitized run-results JSON document from
its actual HTTP calls. Each result records the scenario ID, baseline and
candidate HTTP request counts, pass/fail outcome, observed response class, and
comparison verdict. The scenario manifest records the SHA-256 of the exact API
inventory; run results record the SHA-256 values of both the inventory and
scenario manifest. The coverage checker rejects stale or mismatched artifacts.
The result file is evidence supplied by the suite; the coverage checker does
not send requests or independently authenticate that evidence.

Run the coverage gate from the repository root:

```powershell
& <crow-testing-skill-directory>\scripts\Test-ApiModernizationCoverage.ps1 `
  -RepoRoot <repository-root> `
  -InventoryPath docs\api-inventory.json `
  -ScenarioPath docs\testing\api-scenarios.json `
  -ResultsPath build\api-run-results.json
```

For a monorepo, use the service-scoped inventory path. The gate fails when the
inventory is not `Verified`, source revisions differ, any response-case ID
lacks a scenario, a scenario lacks a result on either side, a recorded result
does not show an HTTP request, a test outcome failed, an error scenario did not
observe an error response class, or a comparison is unresolved. Mutating
operations require the reviewed isolation and cleanup references. A production
target declaration is rejected.

“100% coverage” means every approved success and error response case in the
verified inventory has an approved scenario and that scenario passed over HTTP
against both implementations. It does **not** mean all possible inputs,
branches, code lines, undocumented behavior, or production traffic has been
covered. Report both the operation/response-case counts and any remaining
inventory uncertainty; never turn a missing or failed run into a success.

## Retire the harness deliberately

Keep the comparison harness while both implementations are supported. Agree
on a measurable exit condition with the contract owner; once met, promote the
approved behavior into the replacement's normal API tests and retire the
legacy adapter and differential-only harness. Record intentional behavior
changes and consumer migration decisions with the modernization artifact.
