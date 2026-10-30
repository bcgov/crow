# Entity Framework

Covers EF Core and Entity Framework 6. Confirm the EF version and database
provider first; provider support differs.

## Metadata

- EF Core: set descriptions with `HasComment("…")` (or `[Comment("…")]`) on
  entities and properties, and `ToTable(t => t.HasComment(...))` where the
  repository configures tables that way. The SQL Server provider writes
  `MS_Description`, Npgsql writes `COMMENT ON`, and Pomelo writes the MySQL
  `COMMENT` clause. Check the generated SQL for other providers.
- Oracle (`Oracle.EntityFrameworkCore`): do not use `HasComment` or
  `[Comment]`. Write Oracle comments with `migrationBuilder.Sql(...)` using
  plain `'...'` literals from `New-DataModelMetadataSql.ps1 -Dialect Oracle`
  or `OracleAnnotations`. Verified with provider 10.23.26400:
  - It emits every comment as a national literal (`COMMENT ON ... IS
    N'...'`), even for `VARCHAR2` columns. A failure of that form was
    reported with provider 7.21.9 (dotnet/efcore#32107), and no fix is
    published.
  - A comment-only column change also emits `ALTER TABLE ... MODIFY` for the
    column type and nullability, which fails on `CLOB` columns with
    `ORA-22859` (oracle/dotnet-db-samples#256).
  - Re-check generated SQL after provider upgrades before relaxing this
    rule.
  - If an existing model already has `HasComment` (for example from
    scaffolding), removing it generates comment-drop operations with the
    same defects. Delete those operations from the generated migration, or
    keep the calls and replace the generated statements by hand.
- `HasAnnotation("DataClassification", …)` and
  `HasAnnotation("RecordsSchedule", …)` keep values in the model (matching
  the wwwsqldesigner EF export), but providers ignore unknown annotations
  when generating migrations. Write the database metadata explicitly with
  `migrationBuilder.Sql(...)` in the same migration, using
  `New-DataModelMetadataSql.ps1` output as the starting point, or implement a
  reviewed custom `IMigrationsSqlGenerator`.
- Wrap provider-specific SQL in `if (migrationBuilder.IsSqlServer())` or the
  equivalent provider check when a project targets more than one provider.
- EF6 has no comment API. Add metadata with `Sql(...)` in the `DbMigration`.
- Scaffolding (`dotnet ef dbcontext scaffold`) imports existing comments as
  `HasComment`; it does not import custom extended properties.

## Mapping

- Configure with `IEntityTypeConfiguration<T>` classes per entity, and keep
  database names explicit when the database convention differs from C#.
- Set `HasPrecision(p, s)` for every `decimal`. Use `DateTimeOffset` for
  instants and `DateOnly` and `TimeOnly` where the provider supports them.
- Map value objects with owned types or complex types (EF Core 8+). Use
  value converters for strongly typed IDs and enumerations stored as
  strings.
- Required relationships cascade-delete by default. Set `OnDelete`
  explicitly for every relationship and review cascade paths (SQL Server
  rejects multiple cascade paths).
- Add indexes on foreign keys and query predicates with `HasIndex`;
  `HasFilter` creates filtered or partial indexes where supported.
- Use a token that the provider updates and compares on every write.
  `[Timestamp]` / `IsRowVersion()` maps to SQL Server `rowversion`; use an
  application-managed numeric token with `IsConcurrencyToken()` (incremented
  by every writer or a database trigger) for Oracle and providers without a
  native row-version mechanism. A concurrency-token mapping alone does not
  increment the value.
- Npgsql 7.0+: put `[Timestamp]` or `IsRowVersion()` on a `uint` property to
  map PostgreSQL's `xmin` system column (type `xid`) as the concurrency
  token; verified with Npgsql 10.0.3. Migrations add no column, and
  `UseXminAsConcurrencyToken` is obsolete. Do not add `xmin` to the
  wwwsqldesigner model. From Npgsql 11, serialization failures and deadlocks
  during `SaveChanges` also raise `DbUpdateConcurrencyException`.
- Treat `DbUpdateConcurrencyException` as an expected conflict: reload and
  merge, ask the caller to resolve it, or reject the write. Retry only when
  the operation is safe to repeat and the database reports a transient
  serialization/deadlock failure.
- Use a transaction and provider-supported row locks for short critical
  sections that must serialize work. Review isolation level, lock timeout,
  lock order, and deadlock handling; do not hold locks while waiting on a
  user or remote service.
- SQL Server temporal tables: `ToTable(t => t.IsTemporal())`. The history
  table needs the same metadata and access plan.
- Spatial: NetTopologySuite with the SQL Server or Npgsql spatial plug-in;
  set the SRID on the column type and on geometries.

## Migrations

- Generate with `dotnet ef migrations add`, then read the migration and the
  SQL from `dotnet ef migrations script --idempotent`. Edit the migration
  for safe ordering, batching, and metadata.
- Treat EF Core's `__EFMigrationsHistory` table or EF6's `__MigrationHistory`
  table (schema/name can be configured) as the applied-migration ledger. Do
  not add a competing version table unless the application needs a separate
  compatibility contract.
- Never apply migrations from application start-up in shared environments.
  Deploy scripts or migration bundles through the pipeline.
- Keep the model snapshot consistent; resolve snapshot conflicts by
  regenerating after rebasing. `dotnet ef migrations has-pending-model-changes`
  (EF Core 8+) detects a model that has no migration.
- Do not use `EnsureCreated` with migrations.
- Use `HasData` only for stable reference data; it is not for large or
  environment-specific data.
- Rename columns with `RenameColumn`; EF may otherwise drop and add, losing
  data.

## Testing

- Test migrations and queries against the real engine (for example with
  Testcontainers or a disposable database). The EF in-memory provider does
  not enforce relational constraints, transactions, or SQL translation.
- Assert catalogue metadata after applying migrations.
- Watch for N+1 queries, client evaluation, and cartesian explosion; use
  projection, `AsSplitQuery`, and `AsNoTracking` deliberately.
