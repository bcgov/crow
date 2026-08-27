# .NET secure persistence implementation

This module covers safe implementation only. Database selection, schema/domain modelling, data platform architecture, analytics, and warehouse design are out of scope.

## EF Core

- Register `DbContext` with the correct scoped lifetime. Do not share a context across requests, threads, or background iterations.
- Keep one explicit unit of work per use case. Use an explicit transaction when multiple saves or external coordination require atomicity; do not add transactions mechanically.
- Use async query/save APIs with cancellation.
- Project to the required shape and bound result sizes. Avoid unbounded materialization and accidental N+1 queries.
- Use `AsNoTracking` for read-only queries when change tracking is unnecessary.
- Parameterize raw SQL. Prefer LINQ, `FromSqlInterpolated`, or explicit parameters; never concatenate or interpolate untrusted values into `FromSqlRaw`/`ExecuteSqlRaw`.
- Handle optimistic concurrency explicitly where competing updates matter.
- Apply resilient execution only for transient provider failures and ensure retried operations are safe.
- Verify Unicode-capable column types, database encoding, driver parameters, literals, indexes, and collation with round-trip migrations/tests. Do not assume .NET strings prevent storage-layer corruption.

## Authorization and data access

- Scope protected object queries to the authorized subject/tenant, not only the caller-supplied ID.
- Re-check authorization at the state-changing use case even when the UI filtered available records.
- Prevent mass assignment by mapping allowed request fields into owned entities instead of binding entities directly.
- Do not log SQL parameters that may contain credentials or personal data.

## Dapper and ADO.NET

- Use parameter objects/`DbParameter`; never concatenate values into commands.
- Allowlist dynamic identifiers such as sort columns because parameters cannot represent identifiers.
- Open connections as late as possible, dispose them deterministically, and pass cancellation where supported.
- Keep transaction ownership visible to the use case.

## Migrations

- Generate, review, and test migrations as source-controlled artifacts.
- Prefer a deployment migration step or migration bundle over unrestricted production migrate-on-start.
- If startup migrations are explicitly chosen, use a narrowly privileged identity, distributed coordination, observable failure, and a documented rollback strategy.
- Never swallow migration failure and continue serving against an unknown schema in production.

## Secrets

- Prefer workload/managed identity where supported.
- Otherwise resolve connection material from an approved secret store. Do not commit it or bake it into images.
- Rotate credentials without recompiling the application.

## Required Crow security modules

Load `data-flow-sinks.md`, `auth-and-access-control.md`, and `secrets-and-credentials.md` for persistence changes.

## Sources

- Microsoft Learn, [SQL queries in EF Core](https://learn.microsoft.com/ef/core/querying/sql-queries)
- Microsoft Learn, [Connection resiliency](https://learn.microsoft.com/ef/core/miscellaneous/connection-resiliency)
- Microsoft Learn, [Applying migrations](https://learn.microsoft.com/ef/core/managing-schemas/migrations/applying)
