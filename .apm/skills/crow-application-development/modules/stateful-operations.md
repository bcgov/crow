# Implementing stateful operations

Load when changing a transition, balance/quota, tenant-scoped operation,
transaction, retried delivery, or privileged tool action. Apply only the
relevant domain IDs from
[`stateful-invariants.md`](../../crow-application-architecture/modules/stateful-invariants.md);
the security review's
[`stateful-logic-review.md`](../../crow-security-review/modules/stateful-logic-review.md)
describes how to challenge the implemented behavior.

1. Write down the sourced before/after invariant, every entry point and
   writer, including batch, database, and tool paths, and the failure behavior
   before selecting persistence or API mechanics. Keep enforcement at the
   state/resource boundary so a UI or gateway is not its only guard.
2. Make the decision and the effect atomic where possible: conditional
   transition or compare-and-swap with checked row count, effective lock
   across check and write, or relevant database constraint. Inspect actual
   engine/isolation, transaction propagation and rollback policy rather than
   relying on method annotations alone. Use one unit of work for one business
   operation; justify independently committed audit records.
3. Bind tenant and actor to verified context on each operation, including
   workers and stored procedures. Fail closed on absent context or unavailable
   policy data; reset pooled session/thread context. Authorize tool actions
   independently of model output, and do not trust unsigned forwarded identity
   outside its authenticated hop.
4. Deduplicate retried effects in the same transaction as the mutation, and
   consume one-time tokens atomically. For external side effects use an
   outbox or idempotent calls plus reconciliation; expect delayed and
   out-of-order messages. Define safe recovery for interrupted transitions,
   leaked leases, and partial external failure.
5. Validate arithmetic domains, precision and rounding where state changes;
   never silently accept negative, fractional or client-priced values unless
   the sourced rule permits them. Preserve cancellation and explicit errors.

Use [`crow-testing/modules/stateful-scenarios.md`](../../crow-testing/modules/stateful-scenarios.md)
for focused stateful acceptance tests and safe reproducer boundaries.
