# Evidence-first assessment

## Establish scope without restarting discovery

Read prior reports, decisions, open items and relevant supplied documents.
Inspect manifests, deployment topology, pipeline definitions/templates,
startup/shutdown configuration, migrations, architecture records and runbooks.
Use existing architecture facts rather than recreating an architecture review.
If missing or stale, mark affected facts Unknown and offer the existing
[Architecture Review Agent](../../../agents/crow-architecture-review.agent.md).

Ask once for additional requirements, architecture documents, maintenance and
rollback runbooks, incident findings, and sanitized operational exports.
Pipeline listings do not expose steps: request complete definition exports
where necessary. Repository configuration does not prove deployed state.

Group only remaining material questions:

- Which user operations must succeed, including work begun before maintenance,
  authentication, saved progress, and asynchronous business completion?
- What business hours/time zone, availability measurement point, denominator,
  observation window, and treatment of planned maintenance apply?
- What interruption, latency, failures, lost/duplicate effects, session resets,
  and queue delay are acceptable for each operation? Distinguish outage
  recovery/data-loss objectives from continuous-operation criteria.
- Which release/update/schema scenarios, hosting controls, budgets, operational
  owners, shared services, quotas, and access constraints apply?

Do not silently exclude maintenance from an availability denominator, accept
interruption for the owner, or invent numeric targets.

## Evidence register

For every material fact record its source/path, relevant lines or section,
environment, observation date, applicable application/platform versions,
confidence, and limitation. Confidence is Verified, Inferred, or Unknown;
N/A is applicability, with a reason, not a fourth confidence value.

Distinguish repository configuration, supplied deployed configuration,
supplied measurements, and proposed controls. No live operational provider
access is authorized by this capability. Missing, stale, contradictory, or
unrepresentative evidence stays visible; do not elevate a confidence label
without new evidence or explicit confirmation.

Inspect or request:

| Surface | Required evidence |
|---|---|
| Compute and routing | Deployment manifests or equivalent service/server configuration, actual instance placement, quotas, routing/health/drain controls, capacity with a unit unavailable |
| Delivery | Complete pipelines and scripts, immutable artifact identity, environment approvals, migration ordering, failed-release history |
| State and contracts | Session/key/file/cache stores, APIs/events/consumers, workers/schedulers, transaction/idempotency boundaries, schema/migrations |
| Operations | SLI definitions, representative workload/results, versioned runbooks, alert thresholds, platform and database responsibilities |

Capture source revision and mutable platform/configuration identity separately.
Record `last_confirmed` and `review_after` on changing platform assumptions,
objectives and owner-approved interruption decisions. Re-check on resume.
Preserve resolved items with their resolution date.

## Assessment disposition

A missing input prevents a final decision only where it materially changes
that decision. Deliver an honest gap assessment when possible; stop and ask
when the service boundary, output path, objective, or safety decision cannot
be resolved. Missing evidence is never evidence that a control works.

Host/OS, database-engine maintenance, shared ingress/state services and vendor
operations are dependencies with named teams and evidence limitations.
Their availability or maintenance safety is not established by this report.
