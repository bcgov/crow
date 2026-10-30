# JPA, Hibernate, and Java Data Access

Covers Jakarta Persistence (JPA) with Hibernate, Spring Data JPA, Flyway,
Liquibase, and SQL-first tools such as MyBatis and jOOQ.

## Metadata

- Keep the migration tool as the source of truth for the schema; use JPA
  annotations for mapping and schema validation, not production DDL.
- Liquibase: set `remarks` on `createTable`, `addColumn`, and `column`, and
  use `setTableRemarks` and `setColumnRemarks` for changes. Add structured
  metadata with `sql` changes, guarded by `dbms` attributes for
  multi-engine changelogs.
- Flyway: write comments and structured metadata in the versioned SQL
  migration that creates or changes the object.
- Annotations: Jakarta Persistence 3.2 adds `comment` to `@Table` and
  `@Column`. Hibernate 6 uses `@org.hibernate.annotations.Comment`, which
  Hibernate 7 deprecates in favour of the Jakarta attributes. These only
  affect schema generation; they do not change an existing database.
- MyBatis and jOOQ are SQL-first: place metadata in migrations. jOOQ code
  generation can carry database comments into generated Javadoc.

## Mapping

- Set `spring.jpa.hibernate.ddl-auto=validate` (or `none`) outside local
  experiments; never `update` or `create` against shared databases.
- Use explicit `@Table` and `@Column` names or a reviewed physical naming
  strategy, and confirm the generated names match the database.
- Identifiers: prefer `GenerationType.SEQUENCE` with an `allocationSize` that
  matches the sequence increment; `IDENTITY` prevents insert batching in
  Hibernate.
- Use `BigDecimal` with `precision` and `scale` for money, `Instant` or
  `OffsetDateTime` for instants, and `LocalDate` for dates. Configure
  Hibernate's time-zone storage and the JDBC time zone deliberately.
- Map enums with `EnumType.STRING`, never `ORDINAL`, or with a converter to a
  stable code.
- Use a numeric or timestamp `@Version` field for optimistic concurrency;
  Hibernate includes the loaded version in updates and detects stale writes.
  Confirm the actual column type and update SQL with the target dialect.
  Handle `OptimisticLockException` as a conflict, not as a blind retry.
- Use `LockModeType.PESSIMISTIC_WRITE` only for short transactions that must
  serialize competing work. Set lock timeouts, keep a consistent lock order,
  and handle deadlocks or serialization failures with bounded retries when
  the operation is safe to repeat.
- `@ManyToOne` and `@OneToOne` default to eager fetching; set
  `FetchType.LAZY` and fetch explicitly. Avoid `CascadeType.REMOVE` or `ALL`
  on many-to-many and on large collections.
- Implement `equals` and `hashCode` on a stable business key or identifier
  that does not change on persist.
- Use `@Embeddable` for value objects. Map spatial columns with Hibernate
  Spatial and JTS or Geolatte types; set SRIDs explicitly.
- Hibernate Envers audit tables copy entity data; give them the same
  classification and retention plan.

## Migrations

- Flyway: one versioned, immutable migration per change; never edit an
  applied migration. Use repeatable migrations only for re-creatable objects
  such as views.
- Treat Flyway's `flyway_schema_history` or Liquibase's `DATABASECHANGELOG`
  as the database's applied-migration ledger. Do not duplicate it with a
  second schema-version table unless the application needs a separate
  compatibility contract.
- Liquibase: one change set per logical change, with `id` and `author`
  stable; supply `rollback` blocks for changes Liquibase cannot reverse
  automatically. Use `preConditions` for guarded operations.
- Review the SQL before applying: `liquibase update-sql`, or for Flyway
  `flyway info` plus the migration files themselves. Flyway dry runs
  (`-dryRunOutput`) need a paid edition; otherwise apply to a disposable
  database first.
- Run migrations from the pipeline or a dedicated job, not from multiple
  application instances at start-up unless the tool's locking is verified.

## Testing

- Use Testcontainers or a disposable instance of the real engine; H2 and
  other compatibility modes hide dialect differences.
- Assert catalogue metadata after migration, and run Hibernate schema
  validation in tests.
- Detect N+1 queries with statistics or query-count assertions; use fetch
  joins, entity graphs, or projections.
