# Inspection Prompt: Finite State Machine (FSM) & Lifecycle Audit

> [!IMPORTANT]
> **Governing Doctrine**: All inspections are governed by `instructions.md` (First-Principles Epistemology, Invariant Sourcing, and Four Evidence Levels). The criteria below are investigative prompts, NOT rigid checklist constraints. Accept verified alternative enforcement mechanisms (e.g. database-level check constraints, event-sourcing invariants, or distributed workflow engines) if transition safety is demonstrably maintained.

Execute this inspection when auditing lifecycle transitions, transaction states, and workflow engines.

## 1. FSM Deconstruction & Invariant Sourcing
- Identify all valid states ($S = \{s_0, s_1, ... s_n\}$) and legal transition relations ($T \subseteq S \times S$).
- Locate the authoritative source of the lifecycle rules (business specification, schema enum, or state machine table).
- Extract the implementation mechanism: centralized dispatcher, state machine library, table check constraint, or distributed route handlers.

## 2. Invariant Checklist
- [ ] **Transition Exclusivity**: Are state updates permitted only through verified transition guards, preventing clients from supplying arbitrary target states (`status = req.body.status`)?
- [ ] **Terminal State Locking**: Once an entity enters a terminal state (`CANCELLED`, `COMPLETED`, `REFUNDED`), is further mutation rejected across all entry points?
- [ ] **Constant Writes vs Out-of-Order Lifecycle**: Even when a state assignment uses a hardcoded constant (e.g. `order.status = 'CANCELLED'`), does the handler verify that the current entity state permits cancellation (e.g. not already `SHIPPED` or `FULFILLED`)?
- [ ] **Partial Failure & Rollback Atomicity**: If an intermediate external effect fails during a transition (e.g. payment gateway timeout), does the entity state rollback atomically, or is it left in an inconsistent half-transitioned state?
- [ ] **Compensating Transactions**: Are compensating workflows guaranteed to execute under failure, or can an unhandled exception leave resources orphaned?

## 3. Discriminating Test Vector
```python
def test_illegal_transition_rejection():
    # Sourced Invariant: Order in PENDING status cannot jump directly to COMPLETED
    entity = create_entity(status="PENDING")
    
    with pytest.raises(InvalidStateTransitionError):
        entity.complete()
    
    # Verify entity state remains intact
    assert entity.refresh().status == "PENDING"
```
