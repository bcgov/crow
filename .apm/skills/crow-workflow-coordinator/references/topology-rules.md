# Crow Workflow Topology Rules

These architectural rules govern dependency graph (DAG) construction, concurrency boundaries, and execution safety for multi-agent workflows in Crow.

## Invariant 1: Strictly Acyclic (No Cycles)
A graph manifest must form a finite Directed Acyclic Graph (DAG). Circular dependencies (e.g., node A depends on B, and B depends on A) are strictly prohibited and rejected during manifest validation. For iterative refinement, use the **Bounded Loop** strategy instead of graph cycles.

## Invariant 2: Single-Writer Mutation Boundary
1. Multiple mutation nodes cannot execute in parallel.
2. If two nodes modify repository state (`type: "mutation"`), an explicit dependency edge must order them, or they must be separated by a synchronization barrier.
3. Every mutation node must declare its `mutation_targets` (specific files or subdirectories) and respect `forbidden_paths` (protected infrastructure, CI workflows, and credentials).

## Invariant 3: Safe Concurrent Read Fan-Out
1. Nodes classified as `type: "read_only"` (such as `crow-project-context`, `crow-security-review`, `crow-sonar-scan`, `crow-architecture-review`, and `crow-business-rules`) may execute concurrently up to the configured `max_concurrency` limit (default: 4).
2. Independent read tasks must not mutate the filesystem, write to `.git`, or modify environment configuration.

## Invariant 4: Synchronization and Join Barriers
1. A node that consumes inputs from multiple independent analysis branches must declare all of them in its `dependencies` array.
2. The orchestrator enforces a join barrier: execution of the downstream node pauses until all declared prerequisite nodes achieve terminal success (`status: "succeeded"`).
3. If any prerequisite node fails, downstream nodes are immediately blocked (`status: "blocked"`) unless an explicit fallback policy is defined on the prerequisite.

## Invariant 5: Fail-Closed Verification Gates
1. Each node may declare a `verifier` (a deterministic test command, script assertion, or artifact schema check).
2. A node is certified as succeeded only if both its primary execution and its verifier exit with return code 0.
3. Unverified or partial mutations never propagate to subsequent stages.

## Invariant 6: Isolated Worktree Execution
1. All mutation workflows must execute inside an isolated Git worktree (e.g., `.worktrees/task-<id>`) branched from the target base.
2. The primary working copy remains untouched until all verification steps pass and the user explicitly approves merging the worktree.
