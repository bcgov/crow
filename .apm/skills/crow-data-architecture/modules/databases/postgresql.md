# PostgreSQL and PostGIS

## Metadata

- Use `COMMENT ON TABLE` and `COMMENT ON COLUMN`. PostgreSQL has no
  structured property store for these items, so append the `@bcgov{...}`
  trailer from the metadata-governance module.
- Read comments with `obj_description(oid, 'pg_class')` and
  `col_description(oid, attnum)`, or from `pg_description`.
- `SECURITY LABEL` requires a label provider such as `sepgsql`; do not use it
  for classification unless the platform provides one.
- Generated scripts set `standard_conforming_strings = on` so backslashes in
  descriptions are literal.

## Types

- `text` or `varchar(n)` (`varchar(n)` when the length is a business rule).
  Both have the same storage and performance.
- `numeric(p,s)` for money; avoid the `money` type.
- `timestamptz` for instants and `date` for dates. `timestamptz` stores UTC
  and converts on output using the session time zone. Avoid `timestamp`
  without time zone for instants.
- `boolean`, `uuid`, and `jsonb` (prefer it over `json` unless the original
  text must be preserved).
- Use `GENERATED ALWAYS AS IDENTITY` rather than `serial`.
- `gen_random_uuid()` is built in from PostgreSQL 13; `uuidv7()` is built in
  from PostgreSQL 18. Earlier versions generate UUIDv7 in the application.
- Use `CHECK` constraints or a reference table instead of `enum` when values
  will change; enum values cannot be removed easily.

## Identifiers

- Unquoted identifiers fold to lowercase. Use lowercase `snake_case` and
  avoid quoted mixed-case names, which every query must then quote.
- Identifiers are truncated at 63 bytes by default.

## Integrity and indexing

- Foreign keys are not indexed automatically; add indexes for joins and
  parent deletes.
- Use partial unique indexes for "unique among active rows", expression
  indexes for computed predicates, and exclusion constraints for
  non-overlapping ranges.
- Use GIN for `jsonb`, arrays, and full-text search; BRIN for very large,
  naturally ordered append-only tables.
- Row-level security (`ENABLE ROW LEVEL SECURITY` with policies) enforces
  tenant or ownership filters; table owners bypass it unless `FORCE` is set.
- For optimistic concurrency, the `xmin` system column changes on every row
  update and needs no added column; it is a transaction ID, not a business
  version number. See the Entity Framework module for Npgsql mapping.

## Migration safety

- DDL is transactional, but most `ALTER TABLE` forms take an
  `ACCESS EXCLUSIVE` lock that queues behind long transactions and blocks
  later queries. Set `lock_timeout` and retry.
- Adding a column with a non-volatile default is metadata-only from
  PostgreSQL 11.
- Use `CREATE INDEX CONCURRENTLY` (not inside a transaction block; check for
  invalid indexes after failure).
- Add foreign keys and checks `NOT VALID`, then `VALIDATE CONSTRAINT`
  separately with a weaker lock.
- `SET NOT NULL` scans the table. From PostgreSQL 12, a validated
  `CHECK (col IS NOT NULL)` lets it skip the scan; drop the check
  afterwards.
- Type changes that are not binary-compatible rewrite the table and its
  indexes.

## PostGIS

- Manage `CREATE EXTENSION postgis` and upgrades through migrations, and
  record the PostGIS version.
- Declare typed columns with an SRID: `geometry(Point, 3005)` or
  `geometry(MultiPolygon, 3005)`. Do not use untyped `geometry`.
- Use EPSG:3005 (NAD83 / BC Albers) for B.C. projected storage and
  measurement; use EPSG:4326 for interchange and web APIs; use `geography`
  only for global distance calculations.
- Decide single versus multi geometry types deliberately; mixed types in one
  column complicate consumers.
- Add a GiST index for every column used in spatial predicates, and write
  queries with index-aware predicates such as `ST_Intersects` and
  `ST_DWithin`.
- Validate geometry with `ST_IsValid` (and a check constraint where
  appropriate), repair with `ST_MakeValid`, and transform with
  `ST_Transform` at the boundary rather than storing mixed SRIDs.
- Precise locations can identify people or sensitive sites. Classify
  geometry columns by what they reveal, not by their data type.
- Portable-v1 cannot represent spatial types; record the physical type in
  the column comment and the design record.
