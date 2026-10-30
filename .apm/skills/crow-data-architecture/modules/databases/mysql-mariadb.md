# MySQL and MariaDB

Treat MySQL and MariaDB as related but distinct engines. Confirm the product
and version before applying version-specific advice.

## Metadata

- Use the `COMMENT` clause. Table comments are limited to 2,048 characters
  and column comments to 1,024 characters. Append the `@bcgov{...}` trailer
  from the metadata-governance module; neither engine has a structured
  property store.
- `ALTER TABLE t COMMENT = '...'` changes a table comment. A column comment
  can only be changed by restating the full column definition with
  `MODIFY COLUMN`; an incomplete definition silently drops the type, null,
  default, generated, or collation attributes. The generator therefore emits
  column comments as review notes. Merge them into the migration's full
  column definition.
- Read comments from `information_schema.TABLES.TABLE_COMMENT` and
  `information_schema.COLUMNS.COLUMN_COMMENT`.
- Generated scripts escape backslashes and quotes for the default SQL mode.
  Review them if `NO_BACKSLASH_ESCAPES` is set.

## Types

- Use InnoDB by default for persistent application tables. Consider an
  exception only when its engine semantics are an explicit requirement:
  - MySQL NDB Cluster for a system intentionally designed and operated as an
    NDB cluster; verify its SQL/type/index limits, transaction behavior,
    foreign-key support, and tooling against the target release.
  - `MEMORY` for small, disposable, reconstructible in-memory data only when
    loss on restart, lack of foreign keys and transactions, and memory limits
    are acceptable. Never use it as the sole store for durable business data.
  - A non-InnoDB engine required by a legacy integration or existing data
    set; isolate the dependency, document the missing guarantees, and plan
    migration rather than choosing it for a new persistent table.
  Record the concrete requirement and operational consequences. Do not use
  MyISAM for new application tables.
- Use `utf8mb4` with an explicit collation; `utf8`/`utf8mb3` cannot store
  all Unicode characters. Default collations differ between MySQL and
  MariaDB versions, so set them explicitly.
- `DECIMAL(p,s)` for money.
- `DATETIME` for date-times stored in UTC by convention. `TIMESTAMP` converts
  between the session time zone and UTC and has a range ending in 2038; avoid
  it for business dates. Neither engine stores a time-zone offset.
- `BOOLEAN` is an alias for `TINYINT(1)`; add a check constraint if only 0
  and 1 are valid.
- UUIDs: MySQL 8 stores them efficiently as `BINARY(16)` with
  `UUID_TO_BIN(uuid, 1)`; MariaDB 10.7+ has a native `UUID` type.
- JSON: MySQL has a binary `JSON` type; in MariaDB `JSON` is an alias for
  `LONGTEXT` with a `JSON_VALID` check.
- Avoid `ENUM` and `SET` for values that change; use a reference table or
  check constraint.
- Run with strict SQL mode so invalid or truncated values fail instead of
  being converted silently.

## Identifiers

- Table-name case sensitivity depends on `lower_case_table_names` and the
  operating system; use lowercase names everywhere.
- Identifiers are limited to 64 characters.

## Integrity and indexing

- InnoDB requires an index on foreign key columns and creates one if
  missing; name it explicitly.
- InnoDB's MVCC does not by itself detect that a user's previously read row
  has since changed. Use an application-managed version column for
  optimistic conflict detection, or a short `SELECT ... FOR UPDATE`
  transaction when competing work must serialize. Handle deadlocks with a
  bounded retry only for operations safe to repeat.
- `CHECK` constraints are enforced from MySQL 8.0.16 and MariaDB 10.2.1;
  earlier versions parse and ignore them.
- InnoDB clusters rows by primary key. Prefer a compact, increasing key;
  every secondary index stores the primary key.
- There are no partial indexes. Emulate "unique among active rows" with a
  generated column that is `NULL` for inactive rows and a unique index on it.
- Spatial: MySQL 8 enforces a column `SRID` attribute and uses it for
  spatial indexes; `SPATIAL` indexes require `NOT NULL` columns. MariaDB
  spatial and SRID support differs; verify for the version in use.

## Migration safety

- DDL causes an implicit commit and cannot be rolled back. Make each step
  re-runnable and plan roll-forward.
- Specify `ALGORITHM=INSTANT` or `ALGORITHM=INPLACE, LOCK=NONE` so a change
  fails instead of silently copying and locking the table. Supported
  operations differ by product and version.
- For large tables, use an online schema change tool such as `gh-ost` or
  `pt-online-schema-change` where the platform allows it, and account for
  replication lag.
- Changing a column's type, length, or character set often copies the table.

## Security features

- Neither engine has native row-level security or sensitivity
  classification. Enforce row filtering through views, stored routines, or
  the application, and test it.
- Encryption at rest and data masking depend on edition and version (for
  example MySQL Enterprise or MariaDB plugins); confirm with the platform
  team.
