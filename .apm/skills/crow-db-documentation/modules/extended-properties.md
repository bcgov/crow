# SQL Server Extended-Property Documentation

Load this module for D1 source-database or D2 warehouse documentation. It
defines the reusable SQL Server metadata contract; the agent still owns scope,
inference, interview questions, confirmation, and write decisions.

## Property contract

`MS_Description` is the primary human-readable description. Set it first and
never replace an existing value without explicit approval.

| Property | Applies to | Expected value |
|---|---|---|
| `MS_Description` | database, schema, table, view, procedure, function, trigger, column, constraint | Observable business meaning, purpose, or rule |
| `BusinessDescription` | table, column | Plain-language explanation where the technical description is insufficient |
| `SourceSystem` | table, column | Originating system or feed |
| `SourceTable` | table | Originating table/entity |
| `SourceColumn` | column | Originating attribute |
| `Grain` | fact table | What one row represents |
| `TableType` | table | `Fact`, `Dimension`, `Bridge`, `Staging`, `Reference`, or `Archive` |
| `SCDType` | dimension table | `1`, `2`, `3`, `6`, or `None` |
| `ConformedDimension` | dimension table | `Yes` or `No` |
| `KeyColumn` | column | `SurrogateKey`, `NaturalKey`, `ForeignKey`, `Measure`, `Attribute`, or `Flag` |
| `InformationType` | column | Classification taxonomy below |
| `SensitivityLabel` | table, column | `Unreviewed`, `Public`, `Protected A`, `Protected B`, or `Protected C` |
| `BusinessOwner` | table | Accountable team or role |
| `DataSteward` | table | Data-quality owner |
| `RefreshFrequency` | table | `Daily`, `Hourly`, `Weekly`, `Monthly`, or `On-demand` |
| `ExecutionContext` | procedure, function, trigger | Calling job, package, application, or dependency |
| `RelatedReport` | table, view | Consuming report or semantic model |
| `InferredRelationship` | inferred FK column | Target, cardinality, basis, and confirmation state |

For D2, the required baseline is:

- all tables: `MS_Description`, `TableType`, `BusinessOwner`,
  `DataSteward`, `RefreshFrequency`, and `SourceSystem`;
- facts: also `Grain`;
- dimensions: also `SCDType` and `ConformedDimension`;
- documented columns: `MS_Description`, `KeyColumn`, `SourceColumn` where
  applicable, and confirmed classification properties.

Do not invent organization-specific property names or values. If a project
requires additional properties, show the proposed contract and obtain
confirmation before generating them.

### Shared D2 conventions

When a D2 scope has common metadata, do not repeat identical questions and
draft text for every table. Create a confirmed convention record for the
selected scope, for example:

```text
Scope: DW database / dbo schema
BusinessOwner: Finance Data Services
DataSteward: Finance Data Quality
RefreshFrequency: Daily
SourceSystem: Finance ERP
AppliesTo: 42 tables
Exceptions: dbo.FactAdjustment, dbo.DimCurrency
Confirmation: pending|confirmed
```

Review the convention once, present the affected object count, and show only
exceptions or objects with conflicting existing values. A convention reduces
interview and review repetition; it does not create SQL Server inheritance.
If the contract requires table-level extended properties, the approved output
must still expand the convention to each applicable table. Existing values
remain protected: report conflicts and request an explicit overwrite decision
per property or for the confirmed batch.

Store the confirmed convention in the target project's
`design/decisions.md` when that register exists, and reference it from the
coverage and session outputs. If no decisions register exists, keep the
convention in the project-local coverage/session artifacts and state that it
is not yet reusable across sessions. Scope conventions narrowly; do not apply
a database-wide value to a schema or table that has a different owner,
steward, refresh pattern, source, sensitivity, or business role.

## Classification safeguards

Use exact casing. New or unclassified fields may be marked `Unreviewed`, but
the agent must not silently assign a sensitivity label inferred from a name.
Inferred PII requires explicit user confirmation, especially for `Protected B`
or `Protected C`.

| InformationType | Examples |
|---|---|
| `Unreviewed` | Default until reviewed |
| `Banking` | Account, routing, or transit number |
| `Contact Info` | Address, postal code, phone, email |
| `Credentials` | Username, password hash, account identifier |
| `Credit Card` | Card number, expiry, CVV |
| `Date of Birth` | Birth date or birth year |
| `Financial` | Invoice, payment, tax, or wage amount |
| `Free-form Text` | Comments, notes, memo, description |
| `Health` | Health, PHN, or MSP number |
| `Identification` | Passport, driver's licence, or identification number |
| `Name` | First, last, middle, alias, or legal name |
| `Networking` | IP, MAC, or host name |
| `Personal` | Gender, race, indigeneity, ability, or education |
| `SIN` | Social Insurance Number |
| `Other` | Only when no more specific category applies |

Table sensitivity is the highest confirmed sensitivity of its columns. Use
`Protected C` only when the user confirms the exceptional risk and appropriate
privacy authority is involved.

## Safe T-SQL patterns

Use schema-qualified names and `sys.` procedures. Values are drafts until
confirmed. Generate scripts for review when direct application is unavailable
or not explicitly authorized.

```sql
EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'<confirmed description>',
    @level0type = N'SCHEMA', @level0name = N'<schema>',
    @level1type = N'TABLE',  @level1name = N'<table>';
```

For a column, add:

```sql
    @level2type = N'COLUMN', @level2name = N'<column>';
```

For a constraint, add:

```sql
    @level2type = N'CONSTRAINT', @level2name = N'<constraint>';
```

Database-level and schema-level descriptions use the corresponding scope:

```sql
-- Database
EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'<confirmed database purpose>';

-- Schema
EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'<confirmed schema purpose>',
    @level0type = N'SCHEMA', @level0name = N'<schema>';
```

For deployment-safe scripts, update only a property the user approved for
change. Use the idempotent add-or-update form:

```sql
IF EXISTS (
    SELECT 1
    FROM sys.extended_properties
    WHERE major_id = OBJECT_ID(N'<schema>.<table>')
      AND minor_id = 0
      AND class = 1
      AND [name] = N'MS_Description'
)
    EXEC sys.sp_updateextendedproperty
        @name = N'MS_Description',
        @value = N'<confirmed description>',
        @level0type = N'SCHEMA', @level0name = N'<schema>',
        @level1type = N'TABLE', @level1name = N'<table>';
ELSE
    EXEC sys.sp_addextendedproperty
        @name = N'MS_Description',
        @value = N'<confirmed description>',
        @level0type = N'SCHEMA', @level0name = N'<schema>',
        @level1type = N'TABLE', @level1name = N'<table>';
```

For columns, include `minor_id = COLUMNPROPERTY(OBJECT_ID(N'<schema>.<table>'),
N'<column>', 'ColumnId')` in the existence check and add the column level
parameters to both branches. Never use an update branch to overwrite a
pre-existing description unless the user explicitly selected that change.

## Coverage audits

Run the relevant audit before drafting. Local-only runs may parse DDL and
existing scripts, but must state that live row counts, samples, and metadata
were not verified.

### D0 database and schema context

Inspect database-level (`class = 0`) and schema-level (`class = 3`) properties.
Every non-system schema should have a confirmed purpose before sign-off.

### D1 source database

Audit user tables and views, then columns on documented tables, procedures and
functions, triggers, and non-obvious constraints. The core live-query shape is:

```sql
SELECT
    s.[name] + N'.' + o.[name] AS QualifiedName,
    o.type_desc AS ObjectType
FROM sys.objects AS o
JOIN sys.schemas AS s ON s.schema_id = o.schema_id
LEFT JOIN sys.extended_properties AS ep
    ON ep.major_id = o.object_id
   AND ep.minor_id = 0
   AND ep.class = 1
   AND ep.[name] = N'MS_Description'
WHERE o.[type] IN ('U', 'V', 'P', 'FN', 'IF', 'TF')
  AND s.[name] NOT IN (N'sys', N'INFORMATION_SCHEMA')
  AND ep.major_id IS NULL
ORDER BY QualifiedName;
```

Triggers and CHECK constraints are separate audit surfaces because they encode
invisible behavior:

```sql
SELECT
    s.[name] + N'.' + parent_o.[name] + N'.' + tr.[name] AS QualifiedName
FROM sys.triggers AS tr
JOIN sys.objects AS parent_o ON parent_o.object_id = tr.parent_id
JOIN sys.schemas AS s ON s.schema_id = parent_o.schema_id
LEFT JOIN sys.extended_properties AS ep
    ON ep.major_id = tr.object_id
   AND ep.minor_id = 0
   AND ep.class = 1
   AND ep.[name] = N'MS_Description'
WHERE tr.is_ms_shipped = 0
  AND ep.major_id IS NULL;
```

For columns, prioritize columns on already documented tables and apply the
Convention-versus-Surprise test. Do not create noise for obvious attributes.

### D2 warehouse completeness

Restrict the object scope to `Dimension`, `Fact`, `Staging`, `Internal`, and
`SSAS`. In addition to missing `MS_Description`, report missing required
table-level properties. Facts require `Grain`; dimensions require `SCDType`
and `ConformedDimension`.

When a project uses SSDT, the normal script destination is a project-local
post-deployment path such as `Scripts\Post-Deployment\Documentation\`.
Do not write that project path into the Crow package; return it as a
project-specific output decision.

## Relationships and constraints

Document non-trivial relationships separately from column meaning:

- defined FK: attach `MS_Description` to the FK constraint;
- inferred relationship without an FK: retain the column's own
  `MS_Description` and add `InferredRelationship` to the column;
- include target, cardinality, optionality, business meaning, special
  sentinel/soft-delete rules, inference basis, and confirmation date;
- attach the business reason for CHECK constraints to the constraint, not only
  the expression.

Never overload a column's `MS_Description` with relationship metadata.

## Description and interview rules

Use present tense and explain what the object is before how it is loaded.
Quantify grain when known. Keep the first sentence short enough for common
SSMS or modeling-tool tooltips. Do not include credentials, server names,
private paths, or secrets.

Present drafts before asking questions. Batch by table, with the table draft,
relationship drafts, unusual column drafts, evidence, confidence, and the
specific confirmation question. Useful targeted questions include:

- table: business name, purpose, owner/steward, source system, refresh
  frequency, and whether the draft is accurate;
- column: boolean/status domain, source mapping, business unit/currency, and
  confirmed sensitivity label;
- procedure: caller, load purpose, idempotency, and execution context;
- constraint or relationship: business reason, cardinality, optionality, and
  whether an inferred relationship is confirmed.

Skip questions answered by repository evidence or a confirmed convention. A
conflict with a glossary or decision register stops drafting for that object,
records the conflict, and lets non-conflicting work continue.

## Exclusions and read-only fallback

Unless explicitly included, skip system and metadata objects (`sys.*`,
`INFORMATION_SCHEMA.*`, temporary tables, replication/diagram metadata),
`RowVersion`/`timestamp` columns, and objects outside the selected D1/D2
scope. Record every skip and its reason.

If the user cannot authorize a write, complete discovery, drafting, and
interview, then generate a complete idempotent script for the user or their
change process. Report coverage after application as `pending` rather than
claiming the database was updated.
