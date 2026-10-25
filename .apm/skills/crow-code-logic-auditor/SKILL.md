---
name: crow-code-logic-auditor
description: >-
  Forensic code logic and invariant auditor for business-logic flaws, FSM
  transition bypasses, TOCTOU races, multi-tenant isolation leaks, and
  resource conservation violations. Use when reviewing ASTs, state machines,
  concurrency windows, authorization boundaries, or legacy enterprise code
  (Oracle PL/SQL, Java EE, .NET 4.x, PHP) that standard SAST misses.
---

# Forensic Code Logic & Invariant Auditor (crow-code-logic-auditor)

Operational skill for identifying architectural and semantic vulnerabilities, broken invariants, and subtle state corruption across modern distributed runtimes and enterprise legacy systems (including Oracle Forms/PL/SQL, Java EE, .NET 4.x, and PHP).

## Contents

- [Constraints](#constraints) • [Progressive Disclosure](#progressive-disclosure) • [Quick start](#quick-start) • [Workflow](#workflow) • [Verification](#verification) • [References](#references)

## Constraints

1. **Epistemological Stance & Anti-Fallacy Guardrails**: Reject appeals to authority (SOC2, vendor certifications, passing SAST), popularity ("industry standard pattern"), or tradition ("has run in production for 15 years"). Treat software strictly as deterministic state machines bounded by physical, resource, and informational limits. (Official platform specifications and DBMS locking manuals are admissible evidence of mechanical semantics.)
2. **Invariant Sourcing Requirement**: Verify the explicit source of an invariant (business rule, schema constraint, API contract, or labeled assumption) before reporting a violation. Do not flag the absence of a preferred design pattern if an alternative verified mechanism enforces the property.
3. **Four Evidence Levels**: Maintain strict separation between evidence status (`CONFIRMED`, `SUSPECTED`, `NON LIQUET`, `REFUTED`) and impact severity (`Critical`, `High`, `Medium`, `Low`).
4. **Beyond Syntactic Linters (Negative Bounds)**: Do NOT use this skill for syntax bugs, formatting/linting, pure third-party CVE dependency scans, or generic code walkthroughs. This skill strictly targets non-syntactic business logic flaws, state desynchronization, FSM transition bypasses, and trust-boundary confusion.
5. **Polyglot & Legacy Scope**: Supports modern async runtimes alongside enterprise legacy environments (Oracle Forms/PL/SQL, Java EE EJB, .NET 4.x WCF/ADO.NET, PHP).

## Progressive Disclosure
1. **Inspection**: Load prompt under [`references/prompts/`](./references/prompts/) matching the domain.
2. **Taxonomy**: Consult [`references/logic_invariants_taxonomy.md`](./references/logic_invariants_taxonomy.md) to classify breaches.
3. **Triage Rules**: Run standalone Semgrep ([`references/rules/semgrep/`](./references/rules/semgrep/)) or CodeQL ([`references/rules/codeql/`](./references/rules/codeql/)).
4. **Proof & Report**: Follow Step 0 + Seven-step doctrine in [`instructions.md`](./instructions.md) to formulate discriminating proof.

## Quick start

```bash
# Review doctrine and select targeted inspection prompt:
cat instructions.md
cat references/prompts/concurrency_toctou_audit.md       # TOCTOU Races
cat references/prompts/state_machine_audit.md             # FSM Transitions
cat references/prompts/multi_tenant_context_audit.md      # Multi-Tenant
cat references/prompts/idempotency_replay_audit.md        # Idempotency
cat references/prompts/authorization_perimeter_audit.md   # Perimeter & Auth
cat references/prompts/legacy_forms_authorization_audit.md # Forms & PL/SQL
cat references/prompts/agentic_tool_boundary_audit.md     # Agentic & MCP
semgrep --test references/rules/semgrep                  # Test triage rules
```

## Workflow

1. **Step 0: Scope & Triage**: Inventory entry points; rank by financial/lifecycle blast radius; document coverage boundary.
2. **Step 1: Observed Facts**: Deconstruct ASTs, control-flow graphs, call sites, state schemas, and database trigger cascades.
3. **Step 2: Hard Boundary Conditions**: Map transaction demarcation, isolation levels, locks, and async context propagation.
4. **Step 3: Competing Reconstructions**: Contrast intended flow against adversarial interleavings; actively inspect for existing defenses.
5. **Step 4: Degradation & Obfuscation Correction**: Uncover silent exception swallows, permissive fallbacks, and un-awaited promises.
6. **Step 5: Incentive & Trust Dynamics**: Interrogate assumptions regarding caller sanity, ambient headers, and client-controlled inputs.
7. **Step 6: Failure Point Mapping**: Pinpoint the exact AST node, source line, or transaction boundary where invariants breach.
8. **Step 7: Discriminating Tests & Proof**: Formulate reproducible property-based assertions; emit `[FINDING-XXX]` or `[NON-LIQUET-XXX]`.

## Verification

```bash
# Test Semgrep AST logic rules against annotated test fixtures
semgrep --test .apm/skills/crow-code-logic-auditor/references/rules/semgrep
python3 .apm/skills/crow-code-logic-auditor/evals/test_codeql.py

# Audit Crow assets against authoring and context thresholds
pwsh .apm/skills/crow-agent-skill-authoring/scripts/Test-CrowAssets.ps1 -StrictContext
```

## References

- Core Standard & Schemas: [instructions.md](./instructions.md)
- Invariants Taxonomy: [references/logic_invariants_taxonomy.md](./references/logic_invariants_taxonomy.md)
- Game Simulation & RL Auditing: [references/game_simulation_rl_auditing.md](./references/game_simulation_rl_auditing.md)
- Tested Semgrep Rules Index: [references/semgrep_logic_rules.md](./references/semgrep_logic_rules.md)
- CodeQL Query Packs & Regression: [references/codeql_taint_recipes.md](./references/codeql_taint_recipes.md)
- Inspection Prompts: [FSM](references/prompts/state_machine_audit.md) • [Multi-Tenant](references/prompts/multi_tenant_context_audit.md) • [TOCTOU](references/prompts/concurrency_toctou_audit.md) • [Idempotency](references/prompts/idempotency_replay_audit.md) • [Perimeter & Auth](references/prompts/authorization_perimeter_audit.md) • [Forms & PL/SQL](references/prompts/legacy_forms_authorization_audit.md) • [Agentic & MCP](references/prompts/agentic_tool_boundary_audit.md)
- Persona Standard: [agents/forensic_systems_analyst.md](agents/forensic_systems_analyst.md)
