# Data Model Design Record: <title>

| Field | Value |
| --- | --- |
| Mode | New model / Model change / Modernization refactoring |
| Status | Proposed / Approved / Implemented |
| Engine and version | |
| ORM and migration tool | |
| Model file | Path or wwwsqldesigner model and version, or "none" |
| Related work | Issue, feature, or modernization record |

## Context

What problem, feature, defect, or modernization goal drives this change.
List the evidence used and the unknowns (volumes, consumers, schedules).

## Decisions

| # | Decision | Alternatives considered | Reason |
| --- | --- | --- | --- |
| 1 | | | |

## Model changes

| Object | Change | Type and nullability | Keys, constraints, indexes | Description | Classification | Records schedule (table/column) |
| --- | --- | --- | --- | --- | --- | --- |
| schema.table | Add table | | | | Highest column level | Plain text: records class title: retention period and starting event (ARCS/ORCS number) |
| schema.table.column | Add column | | | | | Plain text when this column has distinct retention; otherwise governed by table |

## Migration plan

| Step | Action | Lock and duration risk | Verification | Rollback or roll-forward |
| --- | --- | --- | --- | --- |
| 1 | | | | |

Mark irreversible steps. For breaking changes, show expand, backfill,
reconcile, switch, and contract steps.

## Not represented in the model file

Features the wwwsqldesigner model cannot hold (for example spatial types,
check constraints, delete actions, partial indexes) and where they are
implemented.

## Owner decisions required

| Item | Owner role | Needed by | Status |
| --- | --- | --- | --- |
| Classification of schema.table.column | Information owner | | Open |
| Records schedule for schema.table | Records officer | | Open |
| Distinct records schedule for schema.table.column, when applicable | Records officer | | Open |

## Verification

- [ ] Model file validated with `-RequireGovernanceMetadata`
- [ ] Migration applied to a disposable database on the target engine
- [ ] Catalogue metadata matches the model
- [ ] Repository persistence tests pass
- [ ] Consumers notified or updated

## Residual risks

Risks accepted, mitigations, and the owner who accepted them.
