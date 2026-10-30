# Changing an Existing Model

Use for a feature, bug fix, constraint, index, type, or metadata change to a
schema that already holds data or serves consumers.

## Assess first

1. Identify every consumer of the affected objects: application code, other
   services, reports, ETL, views, stored procedures, triggers, replication,
   and exports. Use code search and the database catalogue; record blind
   spots.
2. Measure or ask for row counts, growth, write rate, and maintenance
   windows. Large tables change the safe migration technique.
3. Read the current DDL, database migration-history ledger, and ORM snapshot.
   Never assume the ORM model matches production; check for drift. Treat the
   migration tool's ledger as the applied schema version; add a separate
   compatibility setting only when application startup or mixed-version
   deployment needs one.
4. For a bug fix, state the faulty rule or data, how many rows it affected,
   and whether existing data needs correction. A data correction is a
   separate, reviewed, auditable step, not a side effect of a schema change.

## Classify the change

- **Additive and compatible:** a new nullable column, table, or index. One
  migration can ship before the code that uses it.
- **Tightening:** a new `NOT NULL`, `UNIQUE`, `CHECK`, or foreign key.
  Validate or repair existing data first, then add the constraint. Where the
  engine supports it, create it unvalidated and validate it separately.
- **Breaking:** rename, type change, split, merge, or removal. Use expand and
  contract (parallel change):
  1. Expand: add the new structure alongside the old.
  2. Deploy code that writes both or tolerates both.
  3. Backfill in bounded, resumable, idempotent batches with progress
     logging.
  4. Reconcile row counts, null rates, aggregates, and sampled rows.
  5. Switch reads, then writes, to the new structure, with monitoring.
  6. Enforce final constraints.
  7. Contract: remove the old structure after all consumers have moved and
     the rollback window has closed.

## Migration safety

- Know each engine's locking and online-DDL behaviour for the statement
  (see the engine module). Avoid long table rewrites during business hours.
- Keep schema migrations small and descriptively named. Separate long
  backfills from DDL so a failed backfill does not hold DDL locks.
- Make each step re-runnable or detect prior completion.
- Provide rollback or a documented roll-forward for every step, and say
  which steps are irreversible (data loss, narrowed types).
- Review the SQL the ORM generates; regenerate after rebasing onto newer
  migrations.
- Test migrations against a copy of the real engine and version with
  representative data shape, not an in-memory substitute.

## Metadata

- Add or update descriptions and classifications for every new or changed
  column and the schedule for every new or affected table in the same
  migration. Add a column-level schedule when its retention differs from the
  table's, with an executable field-purge or de-identification plan.
- Reassess classification when a change combines data, adds free text, or
  links a record to a person; combined data can be more sensitive than its
  parts.
- Update the wwwsqldesigner model in the same change and validate it.

## Review gates

- Consumers, volumes, and drift have been checked or listed as gaps.
- Each breaking change has expand, backfill, reconcile, switch, and contract
  steps with owners and exit criteria.
- Data corrections are separate, reviewed, and auditable.
- Rollback or roll-forward is documented for each step.
- Metadata and the model file match the migration.
