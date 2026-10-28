# Application-level stateful invariants

Load when an operation changes durable state, moves value, scopes data to a
tenant, consumes retries/events, or delegates a state-changing action to a
tool. This module covers application behavior and coordination, not physical
database topology, data modelling, queue product selection, or HA design.
Route those infrastructure decisions to the appropriate solution architecture
work. Apply only the relevant domains below; the labels are stable review
categories, not proof that a vulnerability exists.

## Establish the contract first

For each affected operation, identify the invariant and its source: a business
rule, API contract, schema constraint, existing test, or a clearly labeled
assumption to confirm with the owner. List every writer and reader (HTTP,
Forms, batch, stored procedure, trigger, queue consumer, scheduled job, tool),
the state before and after, the transaction/commit boundary, and any identity
or tenant context carried across hops. A UI guard or a successful scan is not
proof that another entry point enforces the same rule.

| # / invariant domain | IDs | Design question and possible enforcement |
| --- | --- | --- |
| 1. Lifecycle integrity | `FSM-BYPASS` | Which `(from, to)` transitions are allowed, including terminal states and recovery from stuck intermediate states? Validate the transition at the write, not only in a UI/Forms trigger; conditional updates must check the affected-row count. |
| 2. Transaction demarcation | `TRANSACTION-DEMARCATION` | Which writes must commit or roll back together? Inventory explicit commits, autonomous PL/SQL transactions, Spring/EJB `REQUIRES_NEW`, proxy/self-invocation, exception rollback policy, and async .NET transaction flow. An independently committed audit record is not necessarily a business-state commit. |
| 3. Conservation and balance | `BALANCE-VIOLATION`, `LOST-UPDATE` | What must be conserved (money, stock, quota), what are the range and rounding rules, and how do concurrent writers preserve them? Use a verified atomic update, lock, version check, or constraint appropriate to the store; do not assume an ordinary transaction prevents lost updates. |
| 4. Tenant and object authorization | `TENANT-LEAK`, `AUTHZ-BYPASS` | Derive the principal and tenant from verified context; scope reads, writes, aggregates, exports, caches, blobs, and jobs. Check database RLS/VPD policies, grants/bypass roles, security-critical triggers, context setup and cleanup on pooled connections/threads, and alternate writers. Missing context must not broaden access. |
| 5. Atomicity and ordering | `TOCTOU-RACE` | Can a second actor change the checked fact before the effect? Couple check and write via conditional update, unique constraint, versioned compare-and-swap, or a lock that covers the same resource and lifetime; check conflict results and retries. |
| 6. Idempotency and replay | `REPLAY-IDEMPOTENCY` | Can network retry, double submission, webhook replay, or queue redelivery repeat an effect? Bind an idempotency key or unique event ID to the effect in the same transaction, consume one-time tokens atomically, and verify nonce/timestamp bounds for signed requests. |
| 7. Dual writes and distributed state | `DUAL-WRITE` | Can a crash occur between a database commit and an event or external call? Define outbox, idempotent downstream effect, reconciliation, and out-of-order delivery behavior rather than assuming two systems share a commit. |
| 8. Input domain and arithmetic | `INPUT-DOMAIN` | Are negative, zero, fractional, overflowing, client-priced, or out-of-range values valid? Define the rule at the state boundary; include precision, time zone, effective-date and clock-skew assumptions when relevant. |
| 9. Resource leases and cleanup | `RESOURCE-LEAK` | Are cursors, readers, connections, locks, leases, and reservations released on success, error, cancellation, and timeout? A lease needs expiry/fencing if ownership can outlive a worker. |
| 10. Degradation and error swallowing | `ERROR-SWALLOW` | Can a failed step, unawaited call, permissive fallback, or caught exception return apparent success after partial work? Specify observable failure and compensation/reconciliation where atomic rollback is impossible. |
| 11. Perimeter inversion and ambient trust | `PERIMETER-BYPASS` | Can a direct API, batch path, or MCP tool bypass gateway/UI/Forms checks? Validate forwarded identity only from an authenticated trusted hop; authorize the operation and resource at every exposed entry point. |
| 12. Data-driven authorization decoupling | `FAIL-OPEN-AUTH` | Do policy-table errors, null/wildcard scope, missing session context, or authorization timeouts expand access? Fail closed and distinguish deny from unavailable policy data, including database-level policy functions and role/privilege tables. |
| 13. Agentic tool-call and LLM boundaries | `AGENTIC-TOOL-LEAK` | Can untrusted model context or tool results cause a privileged state change? Bind tool authority to the invoking principal and action, independently validate arguments and protected resources, and require appropriate approval for irreversible actions. |

## Verify the actual defense

Do not treat the absence of `SELECT ... FOR UPDATE`, an annotation, or an
idempotency header alone as a defect. Conversely, a unique index protects
only the indexed property, not an unrelated balance; a conditional update is
effective only when its predicate covers the invariant and the caller checks
the affected-row count. Establish the deployed database engine, isolation
level, constraint/trigger applicability, lock scope, rollback and retry
behavior, and the paths that can bypass the defense. Serializable isolation
does not imply identical behavior across engines; verify engine semantics in
official documentation before using them to refute a race. If these facts
cannot be verified, record the missing evidence rather than claiming safety.
