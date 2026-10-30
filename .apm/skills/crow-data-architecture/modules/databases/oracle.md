# Oracle Database

## Metadata

- Use `COMMENT ON TABLE` and `COMMENT ON COLUMN` for descriptions. Comments
  are limited to 4,000 bytes. Read them from `USER_TAB_COMMENTS` and
  `USER_COL_COMMENTS` (or the `ALL_` and `DBA_` views).
- On Oracle Database 23ai, and 19c from Release Update 19.28, use schema
  annotations for structured metadata: `"DataClassification"` and
  `"RecordsSchedule"` on the table or column governed by each value. Read
  them from `USER_ANNOTATIONS_USAGE`.
  Annotation values are limited to 4,000 characters.
  - `ANNOTATIONS (ADD "X" 'value')` fails if the annotation already exists.
    In `ALTER`, use `DROP IF EXISTS "X"` then `ADD`, or `REPLACE`.
  - Column annotations are set through
    `ALTER TABLE t MODIFY ("C" ANNOTATIONS (...))`.
- On earlier versions, append the `@bcgov{...}` trailer to the comment, as
  described in the metadata-governance module.
- Generate statements with the `OracleAnnotations` or `Oracle` dialect. Run
  scripts with substitution variables disabled (`SET DEFINE OFF` in
  SQL*Plus and SQLcl) so `&` in descriptions is not treated as a variable.
- With EF Core, write comments through `migrationBuilder.Sql` rather than
  `HasComment`; see the Entity Framework module for the provider's verified
  behaviour.

## Types

- `NUMBER(p,s)` for exact numbers and money; avoid unconstrained `NUMBER`
  for keys and amounts.
- `VARCHAR2(n CHAR)` for text, so lengths count characters rather than
  bytes; maximum length depends on `MAX_STRING_SIZE`. Use `CLOB` for large
  text.
- `DATE` always includes a time to the second. Use `DATE` with a check or
  convention for date-only values, `TIMESTAMP` for fractional seconds, and
  `TIMESTAMP WITH TIME ZONE` for instants with a zone.
- `BOOLEAN` is native from 23ai; earlier versions use `NUMBER(1)` or
  `CHAR(1)` with a check constraint.
- A zero-length string is `NULL`. A `NOT NULL` text column cannot hold an
  empty string, and `''` comparisons do not behave as in other engines.
- Use identity columns (12c+) or sequences for surrogate keys. Native `JSON`
  type is available from 21c; earlier versions use `CLOB` or `BLOB` with an
  `IS JSON` check.
- Spatial data uses `SDO_GEOMETRY` with SRIDs and `USER_SDO_GEOM_METADATA`
  registration before creating a spatial index.

## Identifiers

- Unquoted identifiers are stored in uppercase. Quoted identifiers are
  case-sensitive and must be quoted everywhere. Prefer unquoted names.
- Identifiers are limited to 128 bytes from 12.2; older versions allow 30.

## Integrity and indexing

- Index foreign key columns. An unindexed foreign key can lock the child
  table when parent keys are updated or deleted.
- Oracle has no automatically changing rowversion column. For optimistic
  concurrency, use an application-managed version number updated in the
  same statement/transaction (or a reviewed trigger) and compare the prior
  value in the write predicate. Do not treat `ORA_ROWSCN` as a reliable
  per-row version without validating its granularity and table settings.
- Use `SELECT ... FOR UPDATE` for short operations that must serialize
  competing writers; set `NOWAIT`/`WAIT` deliberately and handle deadlocks
  and lock timeouts.
- Constraints can be created `ENABLE NOVALIDATE` and validated later with
  `ENABLE VALIDATE`, avoiding a long blocking scan.
- Use function-based indexes for expression predicates and unique rules over
  a subset (by indexing an expression that is `NULL` outside the subset).

## Migration safety

- DDL commits implicitly. A migration with several DDL statements cannot be
  rolled back as a unit; make each step re-runnable and plan roll-forward.
- Adding a column with a default is a metadata-only operation in current
  versions.
- `CREATE INDEX ... ONLINE`, online table moves, and
  `DBMS_REDEFINITION` reduce blocking; some online features need Enterprise
  edition.
- Set `DDL_LOCK_TIMEOUT` so DDL waits briefly rather than failing at once.
- Invalidated dependent objects (views, packages, triggers) need
  recompilation; check `USER_OBJECTS` for `INVALID` status after migration.

## Security features

- Use Virtual Private Database or Real Application Security for row-level
  access control, Data Redaction for display masking, and TDE for
  encryption at rest. Redaction is not a substitute for access control.
- Flashback Data Archive and audit trails retain historical data; include
  them in classification and retention planning.
