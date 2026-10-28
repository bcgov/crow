# Stateful logic and invariant review

Load for state transitions, balances or quotas, tenant-scoped state, concurrent
mutations, retried requests/messages, database policies, legacy Forms/PL/SQL,
or agentic tool actions. Use the domain IDs and design questions in
[`crow-application-architecture/modules/stateful-invariants.md`](../../crow-application-architecture/modules/stateful-invariants.md);
do not infer a vulnerability from a keyword or missing preferred pattern.
This is manual analysis, not a replacement for the existing authorization,
API, LLM, logging, or data-flow modules.

## Bounded investigation

1. Inventory HTTP routes, message consumers, jobs, stored procedures,
   triggers, Forms entry points, and tool handlers that touch the same state.
   Prioritize value movement, lifecycle mutation, tenant boundaries, then
   read-only operations. Record the reviewed set and unreviewed paths; do not
   claim full coverage from a partial inventory or a graph result alone.
2. Source the exact invariant from a business rule, schema, API contract, or
   test. Mark an unsourced expectation as an assumption, not a vulnerability.
   Trace a reachable ingress through each writer, repository and policy check
   to its state change with verified `path:line` references. Inspect grants,
   policies, triggers, constraints, and alternative entry points.
3. Map transaction starts/commits, effective isolation and retries, locks,
   async hops, and principal/tenant propagation. Construct a concrete
   competing execution: two interleaved writes, retry after timeout, crash
   between effects, out-of-order delivery, or direct entry bypassing the
   perimeter. Identify the exact step where the sourced invariant fails.
4. Seek the strongest defense: conditional/atomic updates and checked row
   counts, unique/check constraints, version checks, row locks, effective
   RLS/VPD, idempotency in the effect's transaction, or serializable behavior
   *for the actual engine and path*. A unique constraint on an event ID does
   not prevent a lost balance update. Check who can bypass policies and what
   happens when tenant/session context is absent. Verify runtime/engine claims
   against configuration and official semantics; mark unavailable evidence.
5. Specify a discriminating check that fails on the defective path and passes
   with the verified defense. Execute a write-capable reproducer only after
   user approval on a reviewer-created local container/in-memory store or an
   explicitly confirmed disposable target. Never reuse discovered connection
   strings or credentials, or target production or shared staging. If a safe
   target is unavailable, leave execution unverified.

Discovery hints, not findings: inspect `PRAGMA AUTONOMOUS_TRANSACTION` and
explicit commits in Oracle PL/SQL; `REQUIRES_NEW`, self-invoked
`@Transactional`, and exception rollback in Spring/EJB; async
`TransactionScope` and optimistic concurrency in .NET (including Framework
4.x); `SELECT ... FOR UPDATE`, RLS/VPD policy functions and bypass grants
against the actual database engine; persistent-session context in PHP; and
unawaited or swallowed errors across all runtimes. Verify reachability,
configuration and alternative defenses before reporting.

Apply the relevant domain questions to all mutators, not only endpoints:
transition validity and terminal states (`FSM-BYPASS`); partial commits and
proxy/self-invocation (`TRANSACTION-DEMARCATION`); conserved value, atomic
arithmetic and lost writes (`BALANCE-VIOLATION`, `LOST-UPDATE`,
`TOCTOU-RACE`); scope on every read/write and pooled context (`TENANT-LEAK`,
`AUTHZ-BYPASS`); duplicate effects (`REPLAY-IDEMPOTENCY`); cross-system
ordering and reconciliation (`DUAL-WRITE`); bad amount/date/quantity domains
(`INPUT-DOMAIN`); unreleased resources (`RESOURCE-LEAK`); partial success
(`ERROR-SWALLOW`); direct ingress and ambient identity (`PERIMETER-BYPASS`);
database-policy error and null-scope expansion (`FAIL-OPEN-AUTH`); and model
output crossing privileged tool boundaries (`AGENTIC-TOOL-LEAK`).

## Evidence and existing report contract

Keep severity independent from certainty. Record each investigated domain in
[`security-review-template.md` §5.3](../security-review-template.md) with its
sourced rule, reviewed and unreviewed entry points, evidence or refutation,
and any required telemetry. Do not put fine-grained domain IDs into the
synthesis `domains` array: use one broad `StatefulLogic` domain for this
review surface (alongside genuinely distinct domains, if applicable), so
multiple symptoms of one control do not inflate breadth or create a false
theme. Choose OWASP/CWE per verified finding, not by automatic domain mapping.
These investigation labels never
replace Crow's `SEC-NNN` IDs, `Confirmed / Probable / Informational` finding
classification, synthesis schema, or separate validation adjudication status.

| Investigation result | Existing report treatment |
| --- | --- |
| `CONFIRMED`: sourced invariant, verified reachable chain and failing transition/interleaving (by code, trace, or isolated test), with alternative defenses checked | `SEC-NNN` classified `Confirmed`, with domain ID, source, failure point, reproducible condition, impact, and correction in its body. |
| `SUSPECTED`: chain and failure mechanism verified but a material runtime/configuration prerequisite unverified | `SEC-NNN` classified `Probable` only if a concrete path and code evidence satisfy the existing finding rules; name each assumption and the verification needed. Do not inflate to `Confirmed`. |
| `NON LIQUET`: execution path, effective defense, or runtime semantics cannot be determined | No vulnerability finding. Put the affected boundary, missing configuration/telemetry, owner and verification step in template §5.3. |
| `REFUTED`: a defense was verified for the same invariant, actors, rows and entry points | No vulnerability finding. Note the relevant `path:line` defense and scope in template §5.3; do not count as a remediated issue. |

An unverified chain is not a `SUSPECTED` vulnerability or an
`Informational` placeholder. A missing policy document or an automated rule
hit alone is not proof of failure. Preserve the existing
[`security-review-template.md`](../security-review-template.md) and
[`finding-synthesis-and-validation.md`](finding-synthesis-and-validation.md)
output requirements. For `NON LIQUET`, record unresolved runtime conditions
in §5.3 without an active finding. For `SUSPECTED` cases meeting the criteria
above, retain the `Probable` `SEC-NNN` finding and record its named
runtime/configuration prerequisite and verification step in §5.3. This
evidence status is not the synthesis validation disposition.
