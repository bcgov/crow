# Technology-independent development foundation

- Make the smallest coherent change that fully implements the behavior.
- Keep inputs, outputs, errors, and side effects explicit.
- Validate untrusted input at entry points; enforce business invariants where state changes.
- Authenticate identities and authorize operations/resources independently. Never infer authorization from UI visibility.
- Propagate cancellation and timeouts to I/O. Retry only transient, idempotent operations and cap every retry policy.
- Bound concurrency, queues, request/body sizes, pagination, and fan-out. Apply backpressure or load shedding before resource exhaustion.
- Use structured telemetry with stable event names and correlation. Never log secrets, tokens, full credentials, or unnecessary personal data.
- Surface failures through the application's established error contract. Do not swallow exceptions or return success-shaped fallbacks.
- Keep configuration external, typed where supported, and validated before serving traffic.
- Prefer deterministic builds, pinned/locked dependencies, immutable artifacts, and least-privilege runtime identities.
- Tests must assert observable behavior, not implementation details. Cover security denial and failure behavior as first-class cases.
- Keep public contracts backward compatible by default; test serialization and mixed-version behavior when contracts or schemas evolve.
- Prefer designs that make invalid states and ambiguous outcomes difficult or impossible to represent for
  new or actively touched types: use required/non-nullable members, domain/value types, immutable values,
  explicit construction paths, and exhaustive handling for closed sets where the framework and contract
  allow it. Do not speculatively rewrite untouched, stable code to this shape.
- Separate pure decisions from I/O, persistence, and other boundary effects where practical. Inject ambient
  concerns such as time, randomness, and external clients when the behavior needs deterministic control.
- Apply these as targeted implementation choices, not blanket refactoring rules. If a framework or ORM
  requires a mutable/bindable shape, keep that shape at the boundary and enforce domain invariants in a
  separate model only when it adds real value. To identify a concrete testability problem, consult
  [`crow-testing`'s design-smell catalog](../../crow-testing/modules/reference/design-smell-catalog.md); to
  decide whether it is worth fixing and how to justify the change, consult
  [`crow-testing`'s testability-improvements guide](../../crow-testing/modules/reference/testability-improvements.md).
  Load either only when a concrete testability problem is found, not on every change.
- For shared or canonical dependencies, apply the routed platform-alignment
  module: prefer reuse, name the contract owner, request minimal
  purpose/subject-scoped data, and document versioning, migration, and rollback.
- Treat timeout, cancellation, bounded retry, idempotency, fallback, and
  retry-exhaustion behavior as part of the contract. A fallback must not
  silently weaken authorization, identity assurance, data minimization, or
  auditability.
