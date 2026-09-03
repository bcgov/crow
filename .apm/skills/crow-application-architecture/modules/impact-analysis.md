# Bounded change-impact analysis

Use this procedure before changing shared behavior or fixing a bug. It finds
likely affected code without claiming that static analysis is complete.

## Scope

Start from the changed symbols or entry points and inspect:

1. direct and bounded transitive callers with `codebase-memory-mcp`;
2. text, configuration, route, event, and public-contract references;
3. related tests, fixtures, generators, and documentation that define behavior;
4. generated code, reflection, database triggers, queues, and external consumers
   when the repository exposes them.

Use a bounded graph depth and result count appropriate to the change. Fall back
to repository search when the graph is unavailable or its coverage is partial.
Verify the final affected files directly before editing.

## Limitations

Record blind spots such as dynamic dispatch, reflection, generated artifacts,
runtime configuration, database behavior, event consumers outside the
repository, and incomplete indexing. An impact map is not a completeness claim
or a security verdict. Do not delay an urgent safety fix for exhaustive
analysis; disclose the omitted scope and add follow-up verification.

## Completion evidence

Before calling the change complete, report the starting symbols, searches and
graph bounds used, affected tests or contracts considered, unresolved
references, and the remaining manual verification.
