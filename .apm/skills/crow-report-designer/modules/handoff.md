# Design handoff

The bus matrix maps confirmed facts/grains to conformed and local dimensions;
the glossary resolves business vocabulary. The handoff is valid only when it
contains:

```yaml
producer: crow-report-designer
consumer: crow-ssas-tabular-dw-architect
producer_version: <package-version>
status: draft | signed-off
requested_mode: review | scaffold | build-plan
deliverable_type: pbix | rdl | both
signed_off_artifacts: []
artifact_paths: []
evidence_scope: []
confirmed_grain: []
confirmed_bus_matrix: false
confirmed_security_assumptions: false
decisions: []
open_questions: []
deferred_execution: []
architect_notes: []
sign_off_timestamp: <timestamp-or-null>
```

The architect may review a draft payload, but must reject scaffold or build
generation until `status: signed-off`, the required artifact paths exist, and
the confirmation flags are true. The
[Crow SSAS Tabular DW Architect](../../../agents/crow-ssas-tabular-dw-architect.agent.md)
validates Kimball grain, SCD, Tabular/TMDL, DAX, ELT, and deployment concerns.

Before handoff, validate each listed artifact path: it must exist, be
non-empty, and use the expected Markdown format. `spec.md`, `decisions.md`,
`bus-matrix.md`, `glossary.md`, and `entity-map.md` are required for
`requested_mode: scaffold` or `build-plan`. Reject missing files, contradictory
sign-off state, unresolved blocking questions, or a bus matrix that references
entities absent from the entity map.

Handoff to the [Crow DB Documenter agent](../../../agents/crow-db-documenter.agent.md)
loads the [`crow-db-documentation` skill](../../crow-db-documentation/SKILL.md)
and is offered only after an actual build or an explicitly requested
documentation engagement. Do not invoke unrelated agents automatically.
