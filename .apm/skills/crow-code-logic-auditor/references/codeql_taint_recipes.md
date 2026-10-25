# CodeQL Queries: Index and Limits

Queries live in [rules/codeql/](./rules/codeql/), organized as query packs per language. They use the `DataFlow::ConfigSig` / `TaintTracking::Global<...>` module API. Compilation and results must be verified with the regression command below; a checked-in expected result is not an execution receipt.

## Query Catalog

| Query | Language | Classification | Target Invariant & Reachability |
| :--- | :--- | :--- | :--- |
| `python/UnscopedTenantLookup.ql` | Python / Django | TENANT-LEAK | Remote input (`request.GET`, route kwargs) reaching `Model.objects.get/filter` lacking tenant/org keyword scoping |
| `javascript/UnguardedStateTransition.ql` | JS / TS | FSM-BYPASS | Remote input written to `status/state/stage` property without passing a transition barrier guard |

## Execution Protocol

```bash
# From the skill directory: extract both fixtures and assert exact SARIF sinks.
python3 evals/test_codeql.py

# To analyze another repository, first resolve the selected pack's dependencies:
codeql pack install references/rules/codeql/python
codeql database create db --language=python --source-root=<target_repo>
codeql database analyze db references/rules/codeql/python/UnscopedTenantLookup.ql --format=sarif-latest --output=codeql-report.sarif
```

The regression runner requires a CodeQL CLI on `PATH` (or `--codeql /path/to/codeql`)
and registry access or cached query dependencies. It copies packs to temporary storage
and fails on missing tools, analysis errors, missing findings, or extra findings.
The expected sink locations are in [evals/codeql-cases.json](../evals/codeql-cases.json).
These are SARIF expectations, not native CodeQL `.expected` test files: native
[CodeQL tests](https://docs.github.com/en/code-security/how-tos/find-and-fix-code-vulnerabilities/scan-from-the-command-line/test-custom-queries)
extract source beside the query or `.qlref`, whereas this skill keeps fixtures separate.

## Adaptation Guidance
- Tailor the regex in `TransitionGuard` and keyword regex in `isScopingKeyword` to target codebase conventions.
- The JavaScript guard uses `DataFlow::MakeBarrierGuard`, ensuring the guarded node is sanitized strictly on the branch where the guard predicate evaluated to true.
