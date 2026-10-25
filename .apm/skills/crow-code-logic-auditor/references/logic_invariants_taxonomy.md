# Logic Invariants Taxonomy

Comprehensive taxonomy of non-syntactic logic invariants across polyglot cloud services and enterprise legacy systems. Use in Step 6 to classify findings; use the inspection prompts for procedural execution.

## Contents
- [1. Lifecycle Integrity (FSM-BYPASS)](#1-lifecycle-integrity-fsm-bypass)
- [2. Transaction Demarcation (TRANSACTION-DEMARCATION)](#2-transaction-demarcation-transaction-demarcation)
- [3. Conservation & Balance (BALANCE-VIOLATION, LOST-UPDATE)](#3-conservation--balance-balance-violation-lost-update)
- [4. Tenant & Object Authorization (TENANT-LEAK, AUTHZ-BYPASS)](#4-tenant--object-authorization-tenant-leak-authz-bypass)
- [5. Atomicity & Ordering (TOCTOU-RACE)](#5-atomicity--ordering-toctou-race)
- [6. Idempotency & Replay (REPLAY-IDEMPOTENCY)](#6-idempotency--replay-replay-idempotency)
- [7. Dual Writes & Distributed State (DUAL-WRITE)](#7-dual-writes--distributed-state-dual-write)
- [8. Input Domain & Arithmetic (INPUT-DOMAIN)](#8-input-domain--arithmetic-input-domain)
- [9. Resource Leases & Cleanup (RESOURCE-LEAK)](#9-resource-leases--cleanup-resource-leak)
- [10. Degradation & Error Swallowing (ERROR-SWALLOW)](#10-degradation--error-swallowing-error-swallow)
- [11. Perimeter Inversion & Ambient Trust (PERIMETER-BYPASS)](#11-perimeter-inversion--ambient-trust-perimeter-bypass)
- [12. Data-Driven Authorization Decoupling (FAIL-OPEN-AUTH)](#12-data-driven-authorization-decoupling-fail-open-auth)
- [13. Agentic Tool-Call & LLM Boundaries (AGENTIC-TOOL-LEAK)](#13-agentic-tool-call--llm-boundaries-agentic-tool-leak)

---

## 1. Lifecycle Integrity (FSM-BYPASS)
- **Only declared edges**: Every status write must traverse a transition function that validates `(from, to)` against an allow-list. Direct writes (`order.status = body.status`, `UPDATE orders SET status = :s`) bypass it.
- **Transitions are atomic with their check**: `if order.status == 'PAID': ship()` races with concurrent cancellation. Enforce at write time: `UPDATE orders SET status='SHIPPED' WHERE id=:id AND status='PAID'`, checking affected rows == 1.
- **Terminal states stay terminal** (`CANCELLED`, `REFUNDED`, `CLOSED`), enforced by DB constraints/triggers rather than application-only checks.
- **Oracle Forms**: Validation existing only in `WHEN-VALIDATE-ITEM`/`-RECORD` triggers is enforced only for Forms users; batch jobs, SQL*Plus, or modern REST wrappers bypass it. Look for business rules lacking DB constraints, and watch for `:SYSTEM.MESSAGE_LEVEL` suppressing errors or `ON-ERROR` triggers clearing errors without `FORM_TRIGGER_FAILURE`.

---

## 2. Transaction Demarcation (TRANSACTION-DEMARCATION)
- **One business operation, one commit**: Partial commits leave states that no valid transition produces.
- **PL/SQL `PRAGMA AUTONOMOUS_TRANSACTION`**: Commits independently from caller. Correct for audit/error logging; dangerous for business DML. In triggers, it is frequently an unsafe workaround for `ORA-04091` (mutating table) and cannot see the triggering statement's changes.
- **Java EE / Spring**: `REQUIRES_NEW` commits independently of caller. Spring `@Transactional` (and EJB attributes on local `this` calls) is applied by proxy; calling from another method of the same bean bypasses it entirely. Checked exceptions do not roll back by default in Spring (`rollbackFor` needed); `@Transactional` on private methods is silently ignored.
- **.NET**: `new TransactionScope()` defaults to **Serializable** isolation, turning races into deadlocks; `TransactionScopeAsyncFlowOption.Enabled` is required across `await`.
- **Explicit commits inside loops or helpers** invoked from a larger unit of work.

---

## 3. Conservation & Balance (BALANCE-VIOLATION, LOST-UPDATE)
- **Ledger identity**: For each account: $\text{opening} + \sum \text{credits} - \sum \text{debits} == \text{current}$. In double-entry: debits strictly equal credits.
- **Non-negativity**: Enforced by check constraints or conditional updates, not prior reads.
- **Read-modify-write is a lost update** unless the row is locked or the write is conditional. `obj.balance -= x; obj.save()` loses concurrent writes even inside transactions at READ COMMITTED.
- **Money arithmetic**: No binary floats; single rounding rule applied at one point; split allocations must sum to original (largest-remainder or last-item-absorbs).

---

## 4. Tenant & Object Authorization (TENANT-LEAK, AUTHZ-BYPASS)
- **Tenant from credential, not request**: `tenant_id` must come from verified session/token claims, never body, query, or path parameters.
- **Every data access is scoped**: Reads, writes, deletes, aggregates, exports, search indexes, file/blob storage, cache keys, and background tasks.
- **Fail closed on missing context**: Oracle VPD returning `NULL` or `''` when `SYS_CONTEXT` is unset adds no predicate, defaulting to open access. Query builders doing `filter(tenant_id=ctx.tenant_id)` silently omit filters when the value is `None`. Check who holds `EXEMPT ACCESS POLICY` or `BYPASSRLS`.
- **Vertical authorization**: Role checks on every state mutator, not only the UI controller.
- **Context bleed across requests**:
  - .NET `[ThreadStatic]` / `ThreadLocal` does not flow across `await` and keeps stale context on reused pool threads.
  - Java `ThreadLocal` in pooled executors lacking `finally { clean(); }`.
  - PHP: Static variables/singletons in persistent runtimes (Swoole, RoadRunner, FrankenPHP) and persistent DB connection state (`pconnect`, `SET` variables).
  - Python: `contextvars` copied at task creation; module globals shared across requests.

---

## 5. Atomicity & Ordering (TOCTOU-RACE)
- **Check and act in one atomic step**: Prefer single conditional statements, unique constraints, `SELECT ... FOR UPDATE`, optimistic version columns, or application locks with fencing tokens.
- **Isolation level semantics**:
  - Postgres READ COMMITTED: Read-then-write races freely. REPEATABLE READ: Lost updates raise serialization errors (requires retry). SERIALIZABLE: Prevents both.
  - MySQL/InnoDB REPEATABLE READ: Plain `SELECT` then `UPDATE` loses updates; requires `FOR UPDATE` or conditional update.
  - Oracle: Default READ COMMITTED; SERIALIZABLE permits write skew. `ORA_ROWSCN` is block-level unless table was created with `ROWDEPENDENCIES`.
  - SQL Server: Default READ COMMITTED (RCSI off) releases shared locks after read, permitting races.
- **File locks**: `flock` across NFS mounts is emulated or unsupported; do not rely on it across hosts.
- **Ordering**: Consumers of queues and file drops must tolerate out-of-order arrival via sequence numbers or idempotent upserts.

---

## 6. Idempotency & Replay (REPLAY-IDEMPOTENCY)
- **At-least-once delivery means duplicates**: Webhooks, message consumers, client retries, and double clicks must be idempotent via unique constraints in the same transaction as the effect.
- **One-time tokens**: Consumed atomically (`UPDATE ... SET used_at = now() WHERE token = :t AND used_at IS NULL`).
- **Signed requests**: Timestamp and nonce checks preventing captured request replay.

---

## 7. Dual Writes & Distributed State (DUAL-WRITE)
- Writing to a database and publishing an event (or calling an external payment gateway) without an outbox or two-phase commit risks split-brain state. Use a transactional outbox or perform external calls with idempotency keys and reconciliation.

---

## 8. Input Domain & Arithmetic (INPUT-DOMAIN)
- Negative, zero, fractional, or overflowing values for quantities and amounts (e.g. negative transfer becoming a credit). Client-supplied pricing or discount parameters. Integer overflow in sequence counters. Time zone and clock-skew assumptions in expiry checks.

---

## 9. Resource Leases & Cleanup (RESOURCE-LEAK)
- Oracle: Unclosed ref cursors (`OPEN ... FOR`) in persistent sessions causing ORA-01000.
- ADO.NET: Connections and `SqlDataReader` handles omitted from `using` blocks exhausting pool.
- Locks, leases, or reservations acquired without guaranteed release across all error and exception branches.

---

## 10. Degradation & Error Swallowing (ERROR-SWALLOW)
- Catch blocks that log and continue mid-way through a multi-step state mutation. Un-awaited promises. `try/except: pass` around authorization or validation logic. Permissive fallbacks that default open.

---

## 11. Perimeter Inversion & Ambient Trust (PERIMETER-BYPASS)
- **The "Default-Allow" Perimeter Illusion**:
  - Enterprise systems (PHP, Java EE, Oracle Forms) historically assumed an upstream reverse proxy (SiteMinder SSO, WebLogic gateway, VPN) guaranteed authentication. Internal procedures assume arrival equals authorization.
  - **Modern Failure Mode**: Exposing internal endpoints to modern APIs, microservices, or AI MCP tools bypasses the perimeter proxy, exposing un-guarded operations.
- **Ambient Header Trust**:
  - Reading `SM_USER`, `X-Forwarded-User`, or `X-User-Id` directly without cryptographic origin attestation (mTLS, signed JWT with audience verification, or gateway HMAC).
- **Ingress Surface Asymmetry**:
  - Alternate entry points (MCP tool handlers, batch scripts, async message queues) modifying the same domain entity without enforcing the authorization rules applied on the primary REST route.

---

## 12. Data-Driven Authorization Decoupling (FAIL-OPEN-AUTH)
- **Fail-Open on Database Anomaly**:
  - Access control policies stored in relational tables (`SEC_USER_ROLES`, `SEC_PRIVILEGES`).
  - If the query times out, hits an unhandled exception (`WHEN OTHERS THEN RETURN TRUE`), or encounters a `NULL` role grant, access is mistakenly permitted.
- **Wildcard / NULL Scope Expansion**:
  - Queries using `WHERE (:org_id IS NULL OR org_id = :org_id)` where an unsupplied context parameter silently expands authorization across all multi-tenant rows.

---

## 13. Agentic Tool-Call & LLM Boundaries (AGENTIC-TOOL-LEAK)
- **Autonomous Tool Authority**:
  - LLM-orchestrated MCP tools (such as tools mutating VCS repositories, issue trackers, CI pipelines, or databases) executing privileged operations without verifying that the human or service invoking the agent holds the requisite capability.
- **Prompt-to-State Pollution**:
  - Unvalidated tool output or untrusted content fed back into agent execution loops triggering state-mutating actions without secondary confirmation gates.
