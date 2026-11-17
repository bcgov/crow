# Cross-component continuity design

Own the compatibility intervals and acceptance criteria here. Reuse
[architecture principles](../../crow-application-architecture/modules/principles.md),
[stateful invariants](../../crow-application-architecture/modules/stateful-invariants.md)
and [stateful implementation guidance](../../crow-application-development/modules/stateful-operations.md)
rather than duplicating their workflows.

For every applicable row, record current evidence, gap, target control, owner,
verification criterion IDs, and N/A rationale when appropriate.

| Surface | Continuity-specific questions |
|---|---|
| Remaining capacity | Can surviving instances and shared dependencies sustain representative demand while replacements start? Include quotas, placement/failure domains, connection pools, warm-up, surge and retry amplification; replica count is not capacity evidence. |
| State and sessions | Which state is local, shared or rebuildable? Can the same session, authentication proof, key version, cache value and upload be used across old/new instances? Affinity alone is not session failover. |
| Assets and clients | Can already-open clients fetch their versioned assets and call compatible APIs? Retain or otherwise serve older asset versions for the supported client/rollback interval; account for caches and service workers. |
| Startup and health | What makes an instance eligible for real work? Distinguish startup, liveness, readiness and external business-level signals; avoid dependency-coupled restart cascades. |
| Synchronous ingress | How are new requests/connections stopped, routing changes propagated and in-flight requests completed before force termination? Include persistent HTTP connections, uploads and long transactions. |
| Long-lived connections | What happens to WebSockets, SSE, streaming and server-held UI state? Define bounded drain, reconnect/resume, authorization and any owner-accepted interruption; indefinite sessions cannot be wished into a finite drain. |
| Workers and consumers | Stop acquisition separately from finishing/checkpointing active work. Bound drain against job duration, leases/visibility/acknowledgements and termination deadlines. Verify replay/idempotency at business effects, not only message receipt. |
| Scheduling | Can versions run a job twice, miss it, or overlap after a lease expires? Identify fencing, singleton ownership, clocks, catch-up and recovery responsibility. |
| Version overlap | Can old/new producers and consumers read each other's APIs, events, jobs, serialized sessions, cache entries and files? Include external consumers and the supported client age. |
| Data evolution | Can old and new readers/writers coexist across expansion, backfill, validation and eventual contraction? Who establishes locking, transaction duration, load and online-operation behavior? |
| Recovery | Which application/data combinations remain valid after new writes or external effects? Where does simple reversal stop being safe? |

Routing removal, graceful shutdown, and forced termination have interacting
timelines, not a universal sleep value. Design and measure propagation and
drain margins using the actual host, proxy and runtime. Stop accepting new
worker jobs independently of HTTP routing.

For schema work, link to
[Data Architecture model changes](../../crow-data-architecture/modules/model-change.md)
and [platform compatibility](../../crow-application-architecture/modules/platform-alignment.md).
The data owner determines DDL/backfill details, engine/version-specific lock
and timeout limits, reconciliation and migration coordination. An additive or
"online" operation is not automatically non-blocking.

Separate expansion, application transition, backfill/validation and contraction
with explicit gates; defer contraction until old consumers and the rollback
window are retired. Do not prescribe a universal release count, dual writes,
fixed lock timeout, or mandatory forward-only recovery after every new write.
Prove compatibility for the actual change and identify its irreversible effects.
