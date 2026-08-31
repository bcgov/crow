# Repository Inspection

Inspect the classified application or one inventoried service at a time. Cite source evidence for material claims and distinguish `Verified`, `Inferred`, `Unknown`, and `N/A`.

## Discovery tools

Use codebase-memory-mcp when available to identify structure, clusters, entry points, routes, dependencies, and call paths. Refresh stale indexes, check coverage for cited files, and use direct source reading for partial or excluded areas. If the graph is unavailable, warn about reduced coverage and continue with repository search.

## Inspection passes

1. **Metadata and organization:** application name, acronym, lifecycle status, organizational hints, ownership files, and repository URL.
2. **Boundaries and capabilities:** business capabilities, user types, trust boundaries, external integrations, and deployment unit.
3. **Logical structure:** layers, dependency direction, import or namespace seams, entry points, APIs, events, workers, and contracts.
4. **Security architecture:** authentication, authorization, secret management, cryptography, concurrency controls, audit logging, and data classification. Record architecture only; dependency and vulnerability scanning belongs to the security review capability.
5. **Deployment and observability:** CI/CD, infrastructure as code, containers, runtime topology, logging, metrics, traces, health checks, and alerting.
6. **Resilience and recovery:** retries, circuit breakers, graceful degradation, backups, failover, RTO, and RPO.
7. **Architecture decisions:** ADR locations, identifiers, titles, status, dates, and relevant trade-offs.
8. **Unicode and globalization:** apply the routed Unicode module and trace representative Indigenous-language text across input, storage, processing, search, integration, export, rendering, printing, runtime globalization data, and fonts.

## Existing documentation

Use relevant repository documentation as evidence, including `README.md`, `CONTRIBUTING.md`, `CODEOWNERS`, existing `docs/`, environment templates, and pipeline files. Reference existing material instead of copying it.

## Document generation

- Preserve the architecture template's headings and tables.
- Fill discovered values and annotate confidence.
- Use `N/A` only when a capability does not apply.
- Use `Unknown - requires manual review` when evidence is unavailable.
- Replace generic placeholders and example diagrams with repository-specific content.
- Use valid Mermaid node identifiers and balanced syntax; report any syntax that could not be validated.
- Set the initial revision date to the current date.

If a command fails, record the failure and keep the affected assertion `Unknown`. If an inspection pass has no applicable subject, mark the corresponding content `N/A` with a reason. Stop if the repository lacks enough content for a meaningful architecture document.
