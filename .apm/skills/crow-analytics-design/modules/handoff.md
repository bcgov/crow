# Analytics design handoff

The signed-off handoff is a design contract, not permission to build or
deploy. Prepare it only when requested. A handoff to
`crow-data-architecture` is offered for physical relational schema work only
when the user explicitly selects it.

The handoff records:

```yaml
producer: crow-analytics-design
consumer: crow-data-architecture
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

Unless otherwise specified, design artifact paths are repository-relative
paths under `docs/design/analytics/`.

For `status: signed-off`, require all of the following:

- `signed_off_artifacts` and `artifact_paths` both list the non-empty
  `docs/design/analytics/requirements.md`,
  `docs/design/analytics/decisions.md`,
  `docs/design/analytics/bus-matrix.md`,
  `docs/design/analytics/glossary.md`, and
  `docs/design/analytics/entity-map.md` artifacts.
- `evidence_paths` is non-empty and points only to inspected evidence or
  user-confirmed requirements recorded in the artifacts.
- `confirmed_grain` is non-empty, and
  `confirmed_bus_matrix` and `confirmed_security_assumptions` are both
  `true`, including when the user explicitly confirms that no additional
  security or row-filtering assumptions apply.
- No blocking questions remain, sign-off is explicit, and every bus-matrix
  entity is present in the entity map.

A draft can be reviewed, but it does not authorize implementation. Never
mark a handoff signed off merely because its listed paths exist.

Do not auto-run the consumer agent or imply that it accepted the handoff.
Report the selected consumer and any deferred work.
