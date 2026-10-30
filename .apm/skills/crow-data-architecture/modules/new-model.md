# New Data Model

Use for a new application, bounded context, or schema.

## Steps

1. **Scope.** List the business capabilities, the data each owns, external
   systems of record, and data the solution only references. Reuse an
   authoritative source instead of copying data where possible; record the
   custodian and synchronization method for any copy.
2. **Conceptual model.** Name entities in business language, assign an owner
   to each, and mark bounded-context boundaries. Agree terminology with the
   business owner before adding attributes.
3. **Logical model.** Define attributes, candidate keys, cardinality,
   optionality, and business rules. Normalize to third normal form; note
   rules the database will enforce and rules only the application can.
4. **Classification and retention.** For each attribute record the
   description and classification; give every entity a table-level records
   schedule, and add column-level schedules where retention differs. Group
   high-sensitivity attributes when that simplifies controls. Ask for missing
   values instead of guessing.
5. **Physical model.** Choose schemas, types, identity strategy, constraints,
   indexes, collation, and partitioning for the target engine and version.
   Record any non-portable feature and why it is needed.
6. **ORM mapping.** Map entities, value objects, relationships, concurrency
   tokens, and metadata using the ORM module. Inspect the generated
   migration SQL.
7. **Lifecycle.** Define how rows are created, corrected, archived, and
   disposed of, including history, audit, and derived copies.
8. **Model artifact.** Create or update the wwwsqldesigner XML when the
   project uses it; validate it with `-RequireGovernanceMetadata` and record
   what the designer cannot represent.
9. **Version tracking.** Identify the migration-history table that records
   the applied schema version. Prefer the selected migration tool's ledger;
   document a separate compatibility setting only when the application
   needs one.
10. **Verification.** Run the first migration against the real engine in a
   disposable database, query catalogue metadata, and exercise key queries
   with representative volumes where available.

## Outputs

- A design record from the template, covering decisions, rejected
  alternatives, open owner decisions, and lossy designer representations.
- Migrations that include constraints, indexes, and metadata together.
- A validated model file when the project uses wwwsqldesigner.

## Review gates

- Every table has a primary key, owner, description, and records schedule or
  an open decision; any column with distinct retention also has its own
  schedule or an open decision.
- Every column has a type, nullability, description, and classification.
- Candidate keys are unique, foreign keys and delete behaviour are explicit,
  and indexes match stated access patterns.
- Money, time, Unicode, and large-object choices follow the principles.
- No anti-pattern remains without a recorded reason.
