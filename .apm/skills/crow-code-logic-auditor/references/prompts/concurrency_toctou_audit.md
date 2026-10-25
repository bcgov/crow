# Inspection Prompt: Concurrency & TOCTOU (Time-of-Check to Time-of-Use) Audit

> [!IMPORTANT]
> **Governing Doctrine**: All inspections are governed by `instructions.md` (First-Principles Epistemology, Invariant Sourcing, and Four Evidence Levels). The criteria below are investigative prompts, NOT rigid checklist constraints. Accept verified alternative enforcement mechanisms (e.g. database-level optimistic versioning, atomic conditional updates `UPDATE ... WHERE balance >= :amt`, or deterministic serializable transactions).

Execute this inspection when auditing shared resources, balance updates, token redemptions, inventory decrementing, or critical sections.

## 1. Concurrency Model Extraction & Invariant Sourcing
- Identify the explicit consistency and isolation invariant required by the domain (e.g. "Balance must never drop below 0", "A coupon may only be redeemed once").
- Identify shared mutable state: database rows, in-memory caches, global variables, distributed queues.
- Map the execution concurrency model: multi-threaded, single-threaded event loop (Node.js/asyncio), multi-process workers (Gunicorn/Celery), or distributed microservices.

## 2. Invariant Checklist
- [ ] **Check-Then-Act Gaps**: Is there any non-atomic gap between checking a precondition (e.g. `balance >= cost`, `item.is_available()`) and applying the state mutation?
- [ ] **Locking & Atomic Updates**:
  - Does the system use atomic conditional expressions (`UPDATE accounts SET balance = balance - :amt WHERE id = :id AND balance >= :amt`)?
  - If read-then-write is necessary, is pessimistic row locking (`SELECT ... FOR UPDATE`) held for the full duration of the transaction?
  - Are optimistic concurrency tokens (`version_id`, `ETag`) verified on write?
- [ ] **Distributed Coordination**: If distributed locks are employed, do they include fencing tokens to protect against lock expiration during GC pauses or network delays?
- [ ] **Transaction Demarcation**: Are all dependent mutations enclosed in a transaction with an appropriate isolation level (`REPEATABLE READ` or `SERIALIZABLE`) to prevent non-repeatable reads and lost updates?

## 3. Discriminating Race Simulation (Isolated DB Connections & Barrier)

To prove a real database-level TOCTOU or lost-update race condition across transactions, threads must NOT share an in-memory ORM instance or single test transaction. Use `TransactionTestCase` and explicitly cycle or isolate database connections per worker thread. The launch barrier below is a stress-test skeleton, not a deterministic proof: instrument a test-only seam inside `debit_account` after the vulnerable read/check and before the write to force both workers through the race window. Do not put a blocking barrier after acquiring an exclusive row lock. A passing launch-only test cannot refute a race.

> [!WARNING]
> **Database Engine Warning**: SQLite uses database-level locks and serializes all write operations, artificially masking race windows and producing false `REFUTED` outcomes. Dynamic concurrency tests and barriers MUST run against client-server database engines with multi-connection concurrency (e.g. PostgreSQL, Oracle, MySQL).

```python
import threading
from django.test import TransactionTestCase
from django.db import connection, connections
from myapp.models import Account
from myapp.services import debit_account

class ConcurrentDebitRaceTest(TransactionTestCase):
    def test_concurrent_debit_prevents_double_spend(self):
        initial_balance = 100
        debit_amount = 100
        acct = Account.objects.create(balance=initial_balance)
        
        num_threads = 5
        barrier = threading.Barrier(num_threads)
        results = []
        errors = []

        def worker_thread():
            # Close inherited connection so thread creates its own isolated DB connection
            connections.close_all()
            try:
                # Synchronize launch; use an in-service seam for deterministic proof.
                barrier.wait(timeout=10)
                success = debit_account(acct.pk, debit_amount)
                results.append(success)
            except Exception as e:
                errors.append(e)
            finally:
                connections.close_all()

        threads = [threading.Thread(target=worker_thread) for _ in range(num_threads)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()

        successes = sum(1 for r in results if r is True)
        acct.refresh_from_db()

        assert not errors, f"Worker errors invalidate this result: {errors}"
        # Invariant: exactly one debit succeeds; balance must never drop below 0
        assert successes == 1, f"Double-spend detected! Successful debits: {successes}"
        assert acct.balance == 0, f"Balance invariant breached: {acct.balance}"
```
