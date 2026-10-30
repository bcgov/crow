# Modernization Refactoring

Use for large restructuring: consolidating or splitting schemas, normalizing a
legacy model, moving between engines, or replacing a legacy application's
datastore. When `crow-legacy-modernization` requires the datastore to stay
fixed, this work is the separate, explicitly approved data-change effort it
hands off to.

## Discovery

1. Inventory every object: tables, views, procedures, functions, triggers,
   jobs, sequences, synonyms, links, grants, and replication. Include objects
   no repository references, and list external consumers.
2. Profile the data: row counts, null rates, distinct counts, orphans,
   duplicate natural keys, invalid values, encodings, and date ranges.
   Profile in an approved environment; do not copy production data into the
   repository or evidence.
3. Recover implicit rules from code, procedures, triggers, and data. Hand
   business-rule extraction to `crow-business-rules` when rules need owner
   review.
4. Capture existing descriptions, classifications, and records schedules.
   Legacy data without metadata needs owner decisions before migration.

## Target design

- Design the target with the new-model module, then map each source column
  to a target column, a transformation, or an explicit drop decision.
- For each mapping record type changes, precision, time zone and collation
  differences, null handling, and default values.
- For engine moves, compare semantics explicitly: empty string versus null
  (Oracle treats `''` as `NULL`), identifier case folding, `DATE`
  versus timestamp, numeric precision, boolean representation, sequence and
  identity behaviour, transaction isolation defaults, and collation.
- Classification can only stay the same or increase unless the information
  owner approves a decrease. Carry records schedules forward and dispose of
  data that is already past its retention under the schedule, not by
  migration convenience.

## Transition strategy

- Prefer incremental, strangler-style replacement by bounded capability
  over a single cutover.
- Keep one writer per data set. If both systems must write, use an outbox,
  change data capture, or another atomic mechanism with conflict rules and
  reconciliation; do not rely on unsupervised dual writes.
- Use views or an anti-corruption layer to present the old shape to
  consumers that cannot move yet. Give each compatibility object a
  retirement owner and date.
- Make loads repeatable and idempotent so a run can be repeated after a
  fix.

## Reconciliation

Define acceptance thresholds before migration:

- row counts per entity and per partition or period;
- sums and checksums of key numeric and date columns;
- referential integrity and constraint validation in the target;
- sampled record-level comparisons across each transformation rule;
- rejected-row counts with reasons, each owned and resolved.

## Cutover and rollback

- Rehearse the full migration and reconciliation in a production-like
  environment with timing.
- State the rollback point, how writes made after cutover are preserved or
  replayed, and who decides to roll back.
- Freeze or capture source changes during the cutover window.
- Retain the source under its records schedule; do not delete it as part of
  cutover without owner and records-officer approval.

## Review gates

- Complete object and consumer inventory, with blind spots stated.
- Every source column is mapped or explicitly dropped with an owner decision.
- Metadata is carried forward, and classification decreases are approved.
- Reconciliation thresholds and rollback are defined before execution.
- Compatibility objects have retirement owners and dates.
