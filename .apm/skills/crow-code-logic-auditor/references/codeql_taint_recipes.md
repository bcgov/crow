# CodeQL Queries: Index and Limits

Queries live in [rules/codeql/](./rules/codeql/), organized as compilable query packs per language. They use the modern `DataFlow::ConfigSig` / `TaintTracking::Global<...>` module API (the deprecated `TaintTracking::Configuration` class API has been replaced). Verified with CodeQL CLI 2.27.3 against [evals/fixtures/](../evals/fixtures/).

## Query Catalog

| Query | Language | Classification | Target Invariant & Reachability |
| :--- | :--- | :--- | :--- |
| `python/UnscopedTenantLookup.ql` | Python / Django | TENANT-LEAK | Remote input (`request.GET`, route kwargs) reaching `Model.objects.get/filter` lacking tenant/org keyword scoping |
| `javascript/UnguardedStateTransition.ql` | JS / TS | FSM-BYPASS | Remote input written to `status/state/stage` property without passing a transition barrier guard |

## Execution Protocol

```bash
# 1. Create database
codeql database create db --language=python --source-root=<target_repo>

# 2. Execute analysis pack
codeql database analyze db references/rules/codeql/python --format=sarif-latest --output=codeql-report.sarif
```

## Adaptation Guidance
- Tailor the regex in `TransitionGuard` and keyword regex in `isScopingKeyword` to target codebase conventions.
- The JavaScript guard uses `DataFlow::MakeBarrierGuard`, ensuring the guarded node is sanitized strictly on the branch where the guard predicate evaluated to true.
