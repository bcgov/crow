# Mode routing and contracts

Route: A DW schema review; B SSAS Tabular review; C extended-property
generation boundary; D DAX review; E bus matrix; F ELT review; G deployment
review; H DW schema scaffold; I Tabular scaffold; J source stored-procedure
generation; K SSIS/catalog configuration; L DAX measure generation; M ADO
pipeline configuration; N full build orchestration; O physical design review;
P source analysis. Selective references only. A–G, O, and P are
review/analysis by default; H–N are conditional plans or scaffolds. The
documentation handoff to `crow-db-documenter` is a collaborator contract, not
a replacement mode.

Inputs and outputs must name evidence, assumptions, findings, and unknowns. File edits require confirmation. Live SQL/SSAS, Raven, deployment, and pipeline execution require a reviewed provider/execution contract and explicit confirmation; otherwise mark deferred. Mode N hands off to `crow-db-documenter` only after an actual build, never as an automatic unrelated run.

Mode C is owned by the
[`crow-db-documentation` skill](../../crow-db-documentation/SKILL.md); this
architect may identify required properties but must not duplicate its
documentation policy. Mode O is physical design/index review, not a
documentation handoff.

| Modes | Accepted local inputs | Output | Gate |
|---|---|---|---|
| A–G | SQL/SSDT, BIM/TMDL, DAX, SSIS, pipeline, or design artifacts | Review findings with evidence, assumptions, failed checks, and deferred items | Read-only by default; explicit edit confirmation |
| H–I | Signed-off design payload plus local DW/Tabular inputs | Reviewable DW or Tabular scaffold/plan; never an executed deployment | Require `status: signed-off`; execution contract required for runtime actions |
| J–M | Signed-off source/design inputs plus local project conventions | Proposed source SPs, SSIS/catalog configuration, DAX definitions, or ADO pipeline configuration | Generated artifacts require explicit write approval; runtime execution is deferred |
| N | Complete signed-off design payload and validated prerequisites | Ordered build plan/delivery manifest and handoffs (**not executed; plan/validation checklist only**) | Stop on missing artifact, failed prerequisite, or unapproved execution |
| O | Local DDL/index definitions or reviewed runtime statistics | Physical-design findings and optional remediation plan | Live statistics require reviewed provider contract |
| P | Local SQL/SSDT/TMDL, CSV/sample files, manual source notes, or reviewed provider result | Source/entity inventory, candidate grains, unknowns, and requested confirmations | Live results require reviewed provider contract |
| Documentation handoff | Actual build outputs or explicit documentation request | Versioned handoff to DB Documenter | User selects handoff; no automatic invocation |

Every mode result must use the common completion shape:
`mode`, `status`, `evidence_paths`, `artifact_paths`, `findings`,
`assumptions`, `failed_checks`, `unsupported_or_deferred`, `confirmations`,
and `next_handoff`.
