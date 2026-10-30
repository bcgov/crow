---
name: crow-data-architecture
description: Document, design, evolve, review, or refactor relational and file-storage models for Oracle, SQL Server, PostgreSQL/PostGIS, and MySQL/MariaDB with Entity Framework, JPA/Hibernate, Doctrine, or Eloquent. Keeps descriptions, B.C. security classifications, and records schedules in the database and round-trips models through bcgov/wwwsqldesigner portable-v1 XML.
---

# Data Architecture

Use this skill to document an existing relational schema or model, design a
new data model, change an existing model for a feature or bug fix, or plan a
large-scale data-model refactoring during modernization. Application
boundaries belong to `crow-application-architecture`; solution-wide data
responsibility belongs to `crow-solution-architecture`.

## Context-efficient loading

1. Identify the work mode, database engine and version, ORM and migration tool,
   and whether a wwwsqldesigner model exists. Inspect migrations, mappings,
   model snapshots, and DDL before asking.
2. Load [`modules/principles.md`](modules/principles.md) for every task.
3. Load [`modules/metadata-governance.md`](modules/metadata-governance.md) for
   every task that adds or changes a table or column.
4. Load one mode module. For documentation-only work, load
   [`modules/existing-model-documentation.md`](modules/existing-model-documentation.md).
   For modernization, also load `new-model.md` when the target model is
   designed from scratch:
   - [`modules/new-model.md`](modules/new-model.md) for a new application,
     bounded context, or schema;
   - [`modules/model-change.md`](modules/model-change.md) for a feature, bug
     fix, constraint, index, or type change in an existing model;
   - [`modules/modernization-refactoring.md`](modules/modernization-refactoring.md)
     for a large restructuring, consolidation, split, engine move, or legacy
     replacement.
5. Load only the affected database module from `modules/databases/`:
   [`sqlserver.md`](modules/databases/sqlserver.md),
   [`oracle.md`](modules/databases/oracle.md),
   [`postgresql.md`](modules/databases/postgresql.md) (includes PostGIS), or
   [`mysql-mariadb.md`](modules/databases/mysql-mariadb.md). For an engine
   migration, load the source and target modules.
6. Load [`modules/file-storage.md`](modules/file-storage.md) when the model
   stores files, document payloads, or structured XML/JSON outside ordinary
   relational columns, including filesystem, object-storage, or hybrid
   database/file designs.
7. Load only the affected ORM module from `modules/orm/`:
   [`entity-framework.md`](modules/orm/entity-framework.md) (EF Core and EF6),
   [`jpa-hibernate.md`](modules/orm/jpa-hibernate.md) (also Spring Data,
   Flyway, Liquibase, MyBatis, jOOQ), or
   [`php-doctrine-eloquent.md`](modules/orm/php-doctrine-eloquent.md).
   Skip ORM modules for SQL-first projects.
8. Load [`modules/wwwsqldesigner-xml.md`](modules/wwwsqldesigner-xml.md) only
   when reading, creating, or changing a wwwsqldesigner XML model or API
   snapshot.
9. Use [`templates/data-model-change.md`](templates/data-model-change.md) for
   the design or change record unless the repository has an equivalent ADR or
   design template.
10. For another engine or ORM, add a sibling module and route to it here.

Load `crow-application-development` persistence modules only for the code that
implements the change, and `crow-security-review` modules only for the
affected security concern.

## Deterministic scripts

The scripts support Windows PowerShell 5.1 and PowerShell 7+. Resolve
`scripts/` relative to this installed skill directory, not the target
repository. Both scripts only read the model file; they never connect to a
database.

- Validate a model before saving or committing it:
  - Windows PowerShell 5.1:
    `powershell.exe -NoProfile -File scripts/Test-WwwSqlDesignerModel.ps1 -Path <model.xml> -RequireGovernanceMetadata`
  - PowerShell 7+:
    `pwsh -NoProfile -File scripts/Test-WwwSqlDesignerModel.ps1 -Path <model.xml> -RequireGovernanceMetadata`
  Exit 0 passes, 1 has errors, 2 means the file is missing. Treat warnings as
  review items.
- Generate reviewable metadata SQL from a valid model:
  - Windows PowerShell 5.1:
    `powershell.exe -NoProfile -File scripts/New-DataModelMetadataSql.ps1 -Path <model.xml> -Dialect <SqlServer|OracleAnnotations|Oracle|PostgreSql|MySql> [-IncludeSensitivityClassification] [-OmitSchema] [-FoldUnquotedIdentifiers] [-OutFile <file.sql>]`
  - PowerShell 7+: use the same command with `pwsh`.
  The generator requires complete governance metadata and an explicit schema
  outside SQL Server. It sets values but never removes metadata for dropped
  objects. Place the reviewed output in the repository's migration
  mechanism; do not apply it directly to a shared database.

[`resources/example-permit-model.xml`](resources/example-permit-model.xml) is
a synthetic, valid model for format reference only.

## Workflow

### Documentation-only

For documentation-only requests, follow
[`modules/existing-model-documentation.md`](modules/existing-model-documentation.md).
Perform a read-only evidence and coverage pass before drafting, preserve
existing metadata, and write only the requested project-local documentation
after authorization. Skip schema design, migration planning, model
generation, model validation, and persistence tests unless the request also
changes the model.

### Design, change, or modernization

1. Record evidence: engine and version, ORM and migration tool, existing
   conventions, data volumes, access patterns, consumers, and deployment and
   rollback constraints. Mark unknowns; do not guess volumes or schedules.
2. Model at the level the decision needs: conceptual for scope and ownership,
   logical for keys and rules, physical for engine types, indexes, and DDL.
3. Apply the principles and the engine and ORM modules. Record each deliberate
   denormalization, non-portable feature, or anti-pattern exception with its
   reason.
4. Capture descriptions and classifications for columns, a schedule for each
   table, and a distinct column schedule wherever retention differs. Ask the
   information owner or records officer for values that are not evidenced;
   never invent a schedule number.
5. Identify the database's applied-migration version ledger and avoid
   duplicating the migration tool's source of truth. Plan migration order,
   locking, backfill, verification, and rollback for existing data.
6. Validate any wwwsqldesigner model, generate metadata SQL where useful, and
   run the repository's migration and persistence tests against the real
   engine where available.
7. Report decisions, metadata gaps, lossy designer representations, residual
   risks, and the owner approvals still required.
