# Modernization phase gates

Use the [plan template](../resources/modernization-plan-template.md) as a
durable ledger across sessions. Cite source revisions, output paths, stable
rule/scenario IDs, accountable owners, dated approvals, immutable build IDs,
and external execution-evidence references. An unreviewed assumption is not
an approval. Treat each phase as blocked until its prerequisites are met.

## 1. Discover and pin the legacy boundary

- Identify one application/service, owners, entry points, deployment,
  schedules, integrations, datastore, supported environments, and a pinned
  legacy build. Separate facts from inferred or unknown behavior.
- Record each business process: trigger, actor, ordered states/decisions,
  associated rule IDs, observable results, side effects, failures, and source
  evidence. Reconcile with guides and owners via `crow-business-rules`.
- Inventory each external inbound/outbound interface and consumer/owner:
  REST/SOAP routes, methods, schemas, headers and faults; queues and ordering;
  jobs and timing; file names, encoding and byte layout; outbound calls,
  email and transfers; externally consumed DB queries/stored procedures;
  configuration, ports, TLS, authentication and authorization; error,
  retry, audit, and state effects where consumed. Record how each interface
  will be compared. An unknown external consumer is a coverage limitation,
  not evidence that an interface is safe to change.
- Inventory datastore schema, stored logic, data formats, collation, time
  zone, isolation, drivers, startup auto-migrations, writes, and rollback
  compatibility. Keep all unchanged, including "helpful" seed/index changes.

## 2. Approve and run legacy acceptance evidence

- Trace rules/processes and each contract item to approved scenarios,
  including success, errors, authorization, boundary cases, and side effects.
  Tests must run independently of either application's internal implementation
  and be parameterized for the two pinned builds. Use `crow-testing`'s
  scenario and manual coverage organization instead of duplicating steps.
- For REST/SOAP, follow its verified inventory, explicit approval, HTTP
  baseline/candidate runs, pinned build IDs, and coverage gate. For jobs,
  messages, files, or other interfaces use the same test inputs with
  interface-appropriate contract assertions. Byte/order/encoding/metadata
  differences are not cosmetic unless the interface owner proves they are
  outside the contract; do not normalize away external differences.
- Inventory outbound effects before running legacy code. Only use approved
  non-production targets and isolated, equivalent fixtures; require owner
  approval and cleanup/reset before mutating calls. Never clone or replay
  production data, messages, credentials, or traffic. If legacy cannot run
  safely, ask for an existing safe instance; otherwise stop.
- Where automation cannot cover a behavior, document why and create
  business-readable manual checks using `crow-testing`. Human testers run
  them in both apps. QA owns execution evidence outside this repository;
  record only its safe reference and owner confirmation at the phase gate.
  An unexecuted check is not a pass.

## 3. Approve target architecture and delivery

- Compare retaining the current stack with supported alternatives using
  dated official lifecycle and compatibility evidence. Choose in-place,
  side-by-side, or incremental slice delivery on the merits; no forced
  rewrite or technology switch. Preserve all external contracts and the
  datastore in every proposed option. No implicit SOAP-to-REST replacement.
- Produce the solution architecture through its owning skill. Record
  deployment, testability, state, isolation, operational risks, and rollback,
  including whether replacement writes remain readable by the legacy app.
  Design cutover and rollback, but do not perform production deployment here.
- Show the user every proposed visible UI difference (including routes,
  navigation, content and accessibility changes) and obtain explicit
  approval before implementation. Externally consumed HTML/URLs remain
  contracts regardless of UI approval.
- If unavoidable database change is proven necessary, stop; describe why
  preserving it is impossible and hand off schema/data, migration, legacy
  compatibility, rollback, ownership, and test implications separately.
  Resume only when that effort has an approved, proven compatible boundary.
  If required security or platform changes cannot preserve an external
  contract, stop and seek a separate scope decision, not an exception here.

## 4. Build and compare

- Obtain owner approval of the scope, architecture, scenarios, stage plan,
  UI changes (if any), and rollback prerequisites. Implement bounded slices
  using existing application-development guidance. Do not modify the legacy
  implementation just to make it testable without explicit approval.
- Run the same approved scenarios against both pinned builds in equivalent,
  isolated non-production state; compare outputs, errors, processes, external
  side effects and old-app readability of replacement writes. Record actual
  run references, not fabricated results. For HTTP, run the existing
  deterministic API coverage gate and report its exact inventory-scoped
  meaning; for other interfaces, report inventory and scenario counts plus
  gaps, never imply the HTTP gate covered them.
- For each internal difference, obtain an explicit owner disposition:
  correct the replacement, retain the legacy quirk, or approve a deliberate
  *non-contract* change and update its scenarios. For every external
  contract difference, fix it or stop this workflow. Re-run affected checks.
- Human testers compare applicable manual scenarios on both builds and
  provide evidence and confirmation; the agent cannot self-attest. Do not
  mark equivalence or cutover readiness while evidence, approvals, build
  verification, comparison, or rollback validation remains pending.
