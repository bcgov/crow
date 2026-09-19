# DW/SSAS organization design constraints

These constraints were migrated from the source project's decision register.
Apply them when the reviewed project confirms that this source organization
standard is in scope. They do not override explicit user decisions, stronger
platform policy, or evidence that the reviewed project follows a different
standard. Record any exception in the project's decisions artifact.

This file is the active decision surface for the Crow corpus. Treat its
constraints as defaults that can be overridden by explicit user direction or
stronger project evidence.

## Binding constraints

1. **SCD Type 1 is the default.** Do not add SCD Type 2 columns, history
   tables, or current-row infrastructure unless history is explicitly
   confirmed. Do not report missing SCD Type 2 infrastructure as a defect
   under the default.
2. **SSAS Tabular only.** Do not design or review Multidimensional, MDX,
   MOLAP, ROLAP, HOLAP, calculated members, or named sets.
3. **ELT, not ETL.** Transformations belong in SQL Server T-SQL stored
   procedures. SSIS is orchestration only; do not approve business logic in
   SSIS data-flow transforms.
4. **Generated scripts are idempotent.** Use guarded create/create-or-alter
   patterns for tables, views, procedures, indexes, and extended properties.
5. **Do not add `MAXDOP` hints.** Raise a server-tuning concern as advisory;
   leave MAXDOP to the DBA/server policy.
6. **Classic ADO Server pipelines are the source convention.** Do not generate
   YAML, GitHub Actions, or Azure DevOps Services pipeline definitions when
   this convention is confirmed. Treat this as a project convention, not a
   universal Crow platform rule.
7. **Tabular Editor 2 is the source convention.** Do not use Tabular Editor 3
   APIs or TE3-only syntax when this tool constraint is confirmed.
8. **Prefer upstream computation.** Evaluate staging/load stored procedures
   before DW computed columns, SSAS calculated columns, or DAX measures.
   DAX is the last resort for logic that cannot live at a fixed row grain.
9. **Sensitivity defaults are `Unreviewed`.** New tables and columns must not
   default to Public or Protected labels without explicit confirmation.
10. **Keep the DW self-contained.** Do not introduce cross-database names,
    linked servers, `OPENROWSET`, `OPENQUERY`, `BULK INSERT` file paths, CLR,
    `xp_cmdshell`, Database Mail, or Service Broker. Raise a portability
    finding when these are present.

## Execution precedence

Apply this file before detailed pattern references. If a reference suggests a
conflicting pattern, surface the conflict and ask the orchestrator/user to
resolve it; do not silently choose one.
