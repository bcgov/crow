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
- For shared or canonical dependencies, apply the routed platform-alignment
  module: prefer reuse, name the contract owner, request minimal
  purpose/subject-scoped data, and document versioning, migration, and rollback.
- Treat timeout, cancellation, bounded retry, idempotency, fallback, and
  retry-exhaustion behavior as part of the contract. A fallback must not
  silently weaken authorization, identity assurance, data minimization, or
  auditability.
