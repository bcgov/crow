# Adversarial Mental Models & Game Simulation Heuristics

## Contents
- [Executive Summary](#executive-summary)
- [1. The Codebase as an Adversarial Game Environment](#1-the-codebase-as-an-adversarial-game-environment)
- [2. Reward Shaping & Scoring Matrix](#2-reward-shaping--scoring-matrix)
- [3. Monte Carlo Tree Search (MCTS) Interleaving Heuristic](#3-monte-carlo-tree-search-mcts-interleaving-heuristic)
- [4. Operational Application](#4-operational-application)

---

## Executive Summary
This document outlines an **adversarial search heuristic and mental model** for forensic auditors. Complex business logic flaws (TOCTOU race windows, FSM transition bypasses, multi-tenant leaks) rarely appear as static syntax defects; they emerge from dynamic execution sequences and unexpected call interleavings. 

By modeling code auditing as an adversarial game against a state machine—where the auditor systematically searches for illegal state reachability bounded by formal invariants—agents avoid shallow linter pattern matching.

> [!NOTE]
> This framework is an **investigative mental model and reasoning heuristic** for guiding LLM hypothesis generation and verification. It is not an executable reinforcement learning runtime or compiled training loop.

---

## 1. The Codebase as an Adversarial Game Environment

In game-theoretic state exploration:
- **Environment**: The target system's finite state machine (FSM), database transactions, and call graph.
- **Auditor Action Space**: Valid input vectors, API route invocations, MCP tool dispatches, parameter mutations, and concurrent operation interleavings.
- **State Space**: The combined state of database entities, session contexts, tenant discriminators, and in-memory caches.
- **Winning Condition**: Driving the system into an **Invalid Invariant State** (e.g. negative balance, cross-tenant record leakage, unauthorized state transition) while respecting known preconditions.

```
+-------------------------------------------------------------------------+
|                        Game Environment (Target System)                 |
|                                                                         |
|  [Entry Points / Actions]  ---> [State Transitions] ---> [Entity State] |
|   - API Routes                   - Guards                 - Invariants  |
|   - MCP Tools                    - DB Triggers            - Tenancy     |
|   - Worker Queues                - Transaction Scopes     - Balances    |
+-------------------------------------------------------------------------+
                                    ^
                                    | Actions (Interleavings / Payloads)
                                    |
                           [Auditor Reasoning Model]
                                    |
                                    v Reward / Penalty Feedback
+-------------------------------------------------------------------------+
|                  Epistemic Evaluation Matrix                            |
|                                                                         |
|  +100 pts: Confirmed Invariant Breach with Discriminating Reproducer     |
|  +50 pts: Valid Refutation (Proving alternative defense secures state)  |
|  +30 pts: High-Value NON LIQUET with Concrete Telemetry Specification   |
|  +10 pts: State-Space Coverage Expansion                                |
|  -10 pts: Trivial Syntax / Formatting Noise                             |
|  -30 pts: Syntactic Heuristic False Positive (AST pattern != bug)       |
|  -50 pts: Un-sourced Invariant Violation Claim                          |
|  -100 pts: Unproven CONFIRMED Claim (no executed reproducer/static trace)|
+-------------------------------------------------------------------------+
```

---

## 2. Reward Shaping & Scoring Matrix

To align the auditor with the **Four Evidence Levels** and **First-Principles Epistemology**, scoring strictly penalizes premature pattern-matching while rewarding rigorous verification and honest refutation:

| Objective / Action | Points | Invariant & Evidence Criteria |
| :--- | :--- | :--- |
| **Confirmed Invariant Breach** | `+100` | Sourced invariant cited; reachable violation established by an executed reproducer or complete verified static call chain; discriminating test supplied (`CONFIRMED`). |
| **Rigorous Refutation of Plausible Defect** | `+50` | Identifying an apparent vulnerability, rigorously inspecting alternative defenses (e.g. DB check constraints, Postgres RLS, or serializable locks), and proving the invariant is preserved (`REFUTED`). *(Scored only when resolving an automated rule hit or ranked entry point; capped at max 3 findings / +150 pts per audit pass.)* |
| **High-Value Uncertainty Resolution** | `+30` | Identifying ambiguous boundary conditions, issuing `NON LIQUET`, and formulating an actionable telemetry specification or logging hook to resolve it. *(Scored only when resolving an automated rule hit or ranked entry point; capped at max 3 findings / +90 pts per audit pass.)* |
| **Coverage Expansion** | `+10` | Systematic mapping of previously un-audited state transitions, background worker handlers, or MCP tool dispatchers. |
| **Trivial Syntax / Linter Noise** | `-10` | Reporting cosmetic style issues, formatting, or linting warnings out of scope for logic auditing. |
| **Syntactic False Positive** | `-30` | Flagging code as vulnerable purely because a keyword is missing, without verifying whether alternative mechanisms protect the state. |
| **Un-Sourced Breach Claim** | `-50` | Claiming a security or logic flaw without citing an explicit business specification, schema constraint, or contract rule. |
| **Unproven CONFIRMED Claim** | `-100` | Emitting a `CONFIRMED` verdict without an executed test reproducer or complete verified static call chain. |

> [!NOTE]
> **False-Negative Evaluation Check**: In static reward tallying, missed findings incur 0 points directly; however, coverage gaps and false-negative suppression are rigorously penalized and gated via the behavioral test suite ([`evals/task-success.json`](../evals/task-success.json)).

---

## 3. Monte Carlo Tree Search (MCTS) Interleaving Heuristic

Concurrency bugs (TOCTOU, double-spend, distributed lock gaps) are inherently sequential games. Auditors use an MCTS-style interleaving search heuristic to evaluate candidate race windows:

1. **Selection**: Identify two concurrent operations modifying the same resource balance or state machine entity.
2. **Expansion**: Map candidate preemption points (e.g. between check and act, between ORM read and update, or across asynchronous `await` boundaries).
3. **Simulation**: Evaluate hypothetical thread preemption or network pauses at the identified gap. Verify whether database isolation or row locks prevent interleaving.
4. **Verification**: If an interleaving produces an illegal state, formulate a synchronized test vector (`threading.Barrier`) to confirm whether the race is physically realizable.

---

## 4. Operational Application

When auditing target repositories across diverse operational domains:

1. **Autonomous Tool Boundaries & Multi-MCP Gateways**:
   - *Adversarial Goal*: Attempt to trigger a privileged tool (e.g. database migration, VCS mutation, external API dispatch) using an unauthenticated caller or forged header context.
   - *Verification*: Verify whether the tool handler independently checks authorization or implicitly trusts ambient orchestrator context.

2. **Legacy Enterprise Modernization (Oracle Forms & PL/SQL)**:
   - *Adversarial Goal*: Attempt to bypass legacy client validation triggers (e.g. Oracle Forms `WHEN-VALIDATE-RECORD`) by invoking lower-level package procedures, batch jobs, or modern REST API wrappers directly.
   - *Verification*: Verify whether business invariants are enforced in database constraints/triggers or reside solely in legacy client UI logic.
