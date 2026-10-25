---
name: crow-workflow-coordinator
description: Coordinate multi-step tasks across Crow's skills and agents with diagnostic topology selection (direct, graph DAG, bounded loop, parallel batch), dependency validation, isolated worktree execution, and human approval gates.
---

# Crow Workflow Coordinator

Coordinate multi-step tasks involving Crow's skills and agents. Analyzes the task brief, conducts a bounded diagnostic interview, selects an appropriate execution pattern, plans the dependency graph or task packet, and supervises safe execution with explicit human-in-the-loop gates.

## Context-efficient loading

1. Read [`references/strategy-selection.md`](references/strategy-selection.md) to evaluate task topology.
2. Read [`references/crow-asset-catalog.md`](references/crow-asset-catalog.md) to inspect Crow's skills, agents, inputs, and outputs.
3. Read [`references/topology-rules.md`](references/topology-rules.md) and [`references/graph-manifest-schema.json`](references/graph-manifest-schema.json) when constructing dependency graph manifests.
4. Consult [`references/canonical-workflows.md`](references/canonical-workflows.md) for standard security, modernization, and architecture sequences.
5. Do not load unrelated modules until a node specifically invokes them.

## Workflow coordination loop

### 1. Ingest brief and conduct bounded interview
- Read the user's brief, current repository state, and existing review artifacts before interviewing.
- If scope, prerequisites, or execution topology are unresolved, ask **at most three focused questions** (one per turn where possible) with structured options:
  - Option A [Recommended]: Specific topology and sequence.
  - Option B: Alternative scoping or fallback.
- Never ask generic or open-ended questions when the codebase or brief provides the answer.

### 2. Deterministic strategy selection
Evaluate task complexity and select the minimal necessary execution vehicle:
- **Direct Execution:** Single localized edit (1–2 files), low risk, clear solution. Execute immediately in the current thread.
- **Dependency Graph (DAG):** Multi-phase work involving distinct skills/agents, prerequisite dependencies, parallel read-only fan-out, join barriers, or ordered mutations. Compile a `graph-manifest.json`.
- **Bounded Worker Loop:** Single bounded task requiring iterative trial-and-error with a locked verifier (e.g. test-driven bugfix). Author a task packet; enforce the **NO GIT WRITES** rule on the inner worker.
- **Parallel Batch:** Uniform, completely independent tasks partitioned across multiple files or repositories.

### 3. Plan authoring & manifest validation
For Graph (DAG) strategies:
- Author `graph-manifest.json` declaring nodes, assets, dependencies, mutation targets, forbidden paths, and verifiers.
- Validate the manifest using [`scripts/Test-CrowGraphManifest.ps1`](scripts/Test-CrowGraphManifest.ps1).
- Ensure topology complies with [`references/topology-rules.md`](references/topology-rules.md):
  - Strictly acyclic (zero circular dependencies).
  - Single-writer mutation rule: two mutation nodes never run in parallel.
  - Read-only nodes run concurrently up to `max_concurrency`.
  - Mutating nodes execute in an isolated Git worktree (`.worktrees/task-<id>`).
- Present the planned execution graph and strategy to the human operator for confirmation.

### 4. Safe execution supervision
- Run `Invoke-CrowGraphRunner.ps1 -ManifestPath graph-manifest.json`.
- For each node:
  - Execute independent read-only nodes concurrently.
  - Pause at join barriers until all prerequisite dependencies succeed.
  - Run mutations sequentially in the isolated worktree.
  - Require explicit operator approval before irreversible actions.
  - Fail closed: if a prerequisite fails without an explicit fallback, abort downstream execution immediately.

### 5. Verification & closure
- Execute deterministic node verifiers (test suites, build checks, diff audits).
- Record terminal state and execution receipts in `receipt.json`.
- Present git diff and test verification summary to the human operator before merging worktree changes to the base branch.

## Deterministic scripts

- [`scripts/Select-CrowStrategy.ps1`](scripts/Select-CrowStrategy.ps1): Evaluates task briefs and returns recommended execution strategy.
- [`scripts/Test-CrowGraphManifest.ps1`](scripts/Test-CrowGraphManifest.ps1): Validates manifest schema, detects cycles, duplicate IDs, and unsafe concurrent mutations.
- [`scripts/Invoke-CrowGraphRunner.ps1`](scripts/Invoke-CrowGraphRunner.ps1): Schedules and executes graph nodes with worktree isolation and receipt recording.
