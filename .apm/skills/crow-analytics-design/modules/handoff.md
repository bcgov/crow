# Analytics design handoff

The signed-off handoff is a design contract, not permission to build or
deploy. Prepare it only when requested. A handoff to
`crow-data-architecture` is offered for physical relational schema work only
when the user explicitly selects it.

The handoff records:

```yaml
schema_version: "1.0"
producer: crow-analytics-design
consumer: crow-data-architecture
generated_at: <ISO 8601 UTC timestamp>
source_revision: <commit the artifacts were reviewed at>
status: draft | signed-off
requested_work: <specific physical-model task or review>
signed_off_artifacts: []
artifact_paths: []
evidence_paths: []
confirmed_grain: []
confirmed_bus_matrix: false
confirmed_security_assumptions: false
open_questions: []
deferred_items: []
sign_off_timestamp: <timestamp-or-null>
```

Design artifacts live in the repository-relative directory agreed with the
user; the default is `docs/design/analytics/`.

For `status: signed-off`, require all of the following:

- `signed_off_artifacts` and `artifact_paths` both list the non-empty
  `requirements.md`, `decisions.md`, `bus-matrix.md`, `glossary.md`, and
  `entity-map.md` artifacts in the agreed directory, recorded as
  repository-relative paths.
- `evidence_paths` is non-empty and points only to inspected evidence or
  user-confirmed requirements recorded in the artifacts.
- `confirmed_grain` is non-empty, and
  `confirmed_bus_matrix` and `confirmed_security_assumptions` are both
  `true`, including when the user explicitly confirms that no additional
  security or row-filtering assumptions apply.
- No blocking questions remain, sign-off is explicit, and every bus-matrix
  entity is present in the entity map.
- `generated_at` and `source_revision` are recorded. The consumer confirms
  with the user before using a handoff whose revision no longer matches the
  artifacts.

A draft can be reviewed, but it does not authorize implementation. Never
mark a handoff signed off merely because its listed paths exist.

Do not auto-run the consumer agent or imply that it accepted the handoff.
Report the selected consumer and any deferred work.
