# SQL Server and Azure SQL

## Metadata

- Store descriptions and governance values as extended properties:
  `MS_Description` on tables and columns, and `RecordsSchedule` and
  `DataClassification` on the table or column governed by each value.
  Values are `sql_variant` and are limited to 7,500 bytes. Use
  `sp_addextendedproperty` when a property is new and
  `sp_updateextendedproperty` when it exists, checked through
  `sys.fn_listextendedproperty`.
- On SQL Server 2019+ and Azure SQL, optionally also run
  `ADD SENSITIVITY CLASSIFICATION TO schema.table.column WITH (LABEL = N'Protected B', RANK = MEDIUM)`.
  This feeds auditing (`data_sensitivity_information`) and the portal and
  SSMS reports. Re-running the statement overwrites the classification. The
  generator maps Public to `NONE`, Protected A to `LOW`, Protected B to
  `MEDIUM`, and Protected C to `HIGH`; adjust the mapping if the organization
  has another one.
- Keep the extended property as the portable source of truth; it round-trips
  through the designer and EF Core.

Verify:

```sql
SELECT s.name AS schema_name, t.name AS table_name, c.name AS column_name,
       ep.name, CAST(ep.value AS nvarchar(4000)) AS value
FROM sys.extended_properties ep
JOIN sys.tables t ON ep.major_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
LEFT JOIN sys.columns c ON ep.major_id = c.object_id AND ep.minor_id = c.column_id
WHERE ep.class = 1;

SELECT * FROM sys.sensitivity_classifications;
```

## Types

- `nvarchar(n)` for Unicode text, or `varchar` with a UTF-8 collation
  (SQL Server 2019+) when that is the project standard; avoid deprecated
  `text`, `ntext`, and `image`.
- `datetime2` for local or UTC date-times; `datetimeoffset` for instants with
  an offset; `date` and `time` for date-only and time-only values. Avoid
  `datetime` and `smalldatetime` in new designs.
- `decimal(p,s)` for money; avoid `money` and `smallmoney`.
- `bit` for booleans; `uniqueidentifier` for UUIDs. A random UUID clustered
  key fragments the index; cluster on an identity or sequential value
  instead.
- `rowversion` for optimistic concurrency.
- JSON: use the native `json` type only where the target version supports
  it (Azure SQL and SQL Server 2025); otherwise use `nvarchar(max)` with an
  `ISJSON` check.
- Spatial: `geography` for latitude and longitude (SRID 4326) and
  `geometry` for projected coordinates such as EPSG:3005. Add spatial indexes
  for spatial predicates.

## Identifiers and collation

- Database collation governs identifier and data comparison; the common
  default is case-insensitive. Do not rely on case to distinguish names or
  values.
- Set column collation explicitly where case or accent sensitivity is a
  business rule.

## Integrity and indexing

- Every table has a clustered index, normally the primary key. Choose a
  narrow, ever-increasing, immutable clustering key.
- Foreign keys are not indexed automatically; add indexes for joins and
  parent deletes.
- Use filtered unique indexes for rules such as "unique among active rows".
- Consider included columns for covering indexes, guided by query plans and
  Query Store.

## Migration safety

- `ALTER TABLE ... ADD ... NOT NULL DEFAULT <constant>` is a metadata-only
  operation in Enterprise edition and Azure SQL; in other editions it can
  rewrite the table. Check the edition.
- `ONLINE = ON` for index builds and rebuilds needs Enterprise edition or
  Azure SQL; resumable index operations reduce risk on large tables.
- Adding a constraint `WITH NOCHECK` leaves it untrusted, and the optimizer
  ignores untrusted constraints. Repair data, then run
  `ALTER TABLE ... WITH CHECK CHECK CONSTRAINT`.
- DDL is transactional, but large transactions grow the log and block
  readers; batch backfills and set `LOCK_TIMEOUT` for DDL.
- Changing a column type or length can rewrite the table and requires
  dropping dependent indexes, constraints, and schema-bound views.

## Security features

- Use row-level security for tenant or ownership filtering, Always Encrypted
  for columns the database administrators must not read, and TDE for data at
  rest. Dynamic data masking is a convenience, not a security boundary.
- Temporal tables (`SYSTEM_VERSIONING`) copy every change into a history
  table. Give it the same classification, permissions, and retention plan,
  including a history retention policy where supported.
