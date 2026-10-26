# Crow Workflow Topology Rules

These architectural rules govern dependency graph (DAG) construction, concurrency boundaries, and execution safety for multi-agent workflows in Crow.

## Invariant 1: Strictly Acyclic (No Cycles)
A graph manifest must form a finite Directed Acyclic Graph (DAG). Circular dependencies (e.g., node A depends on B, and B depends on A) are strictly prohibited and rejected during manifest validation. For iterative refinement, use the **Bounded Loop** strategy instead of graph cycles.

## Invariant 2: Single-Writer Mutation Boundary
1. Multiple mutation nodes cannot execute in parallel.
2. If two nodes modify repository state (`type: "mutation"`), an explicit dependency edge must order them, including a transitive path through a synchronization barrier.
3. Every mutation node must declare its `mutation_targets` (specific files or subdirectories) and respect `forbidden_paths` (protected infrastructure, CI workflows, and credentials).

## Invariant 3: Safe Concurrent Read Fan-Out
1. Nodes classified as `type: "read_only"` (such as `crow-project-context`, `crow-security-review`, `crow-sonar-scan`, `crow-architecture-review`, and `crow-business-rules`) may execute concurrently up to the configured `max_concurrency` limit (default: 4).
2. Independent read tasks must not alter source files, write to `.git`, or modify environment configuration. Declare separate artifact destinations for reports and scan caches. Commands are trusted code, not sandboxed.

## Invariant 4: Synchronization and Join Barriers
1. A node that consumes inputs from multiple independent analysis branches must declare all of them in its `dependencies` array.
2. The orchestrator enforces a join barrier: execution of the downstream node pauses until all declared prerequisite nodes achieve terminal success (`status: "succeeded"`).
3. If any prerequisite node fails, downstream nodes are immediately blocked (`status: "blocked"`) and the runner returns a non-zero exit code after recording the receipt. Only `fallback.action: "abort"` is supported; other policies are rejected.

## Invariant 5: Fail-Closed Verification Gates
1. Each node may declare a `verifier` (a `command` with a zero exit code or a `file_exists` check with a literal file target; use a command for artifact schema checks).
2. A node is certified as succeeded only if both its primary execution and its verifier exit with return code 0.
3. Unverified or partial mutations never propagate to subsequent stages.

## Invariant 6: Isolated Worktree Execution
1. All mutation workflows must execute inside a pre-created, clean, linked Git worktree (e.g., `.worktrees/task-<id>`) branched from the target base.
2. The runner verifies the supplied worktree root and executes all graph commands there so downstream verification observes the changes. It does not create, merge, commit, or remove worktrees.
3. Mutation scope checks compare file hashes before and after each writer, including tracked and untracked files; scope violations and Git HEAD changes fail the node. These checks detect violations after execution and cannot contain arbitrary shell commands, ignored files, or external side effects.
4. The primary working copy remains untouched until all verification steps pass and the user explicitly approves merging the worktree.

## Runner contract

Every non-barrier node requires a `command` for real execution. Asset names identify existing Crow skills or agents and do not dispatch AI work. A dry run validates topology and simulates nodes, sets `DryRun: true` in the receipt, and certifies no actual work.

The runner honors `max_concurrency` in bounded batches; writers execute alone. A failing batch finishes its active jobs and blocks all pending work. Receipts default to `receipt.json`, including on execution or approval failures. Invalid manifests are rejected before execution.

Approval defaults to `prompt`. For automation, the operator reviews the exact manifest and supplies its SHA-256 via `-ApprovedManifestHash`; `approval_mode: "manifest_hash"` requires that parameter. `approval_mode: "none"` permits only graphs without mutation nodes. Manifest approval does not authorize irreversible actions, which must be handled separately by the supervising operator.
