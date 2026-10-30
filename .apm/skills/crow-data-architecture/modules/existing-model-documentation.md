# Existing model documentation

Load this module for documentation-only work on an existing database schema,
data model, mappings, or local model files. Use the other data-architecture
modules when the request also changes the model.

## Evidence and scope

Confirm the target, documentation mode, object scope, and whether local files
are current. Inspect available DDL, migrations, mappings, model snapshots,
wwwsqldesigner XML, and existing documentation before drafting. Do not query
live databases or claim runtime facts from static files. Mark unavailable
counts, samples, statistics, and metadata as unverified.

Use the Convention-versus-Surprise test: prioritize objects whose business
meaning or behavior is not self-evident, such as complex views, procedures,
triggers, relationships, and business-critical attributes. Skip obvious
fields and system metadata with a reason. Detect repeated conventions once;
report their scope, affected-object count, and exceptions, then ask for one
confirmation before batching.

Draft descriptions only from evidence. Mark inferred content `[INFERRED]`,
state its evidence and confidence, and keep it distinct from confirmed
metadata. Name-based matches may help identify questions but do not establish
business meaning, classification, or retention.

## Metadata safeguards

Load [`metadata-governance.md`](metadata-governance.md) and the affected
database module before proposing metadata writes. Preserve Crow's existing
B.C. security classification values and governance rules. Never introduce
alternate classification values, infer a classification, lower an existing
classification, or treat a classification label as an access control.
Missing or ambiguous classifications and records schedules remain explicit
owner decisions.

Do not silently replace existing descriptions or metadata. Present the
proposed values and a diff, and get explicit approval for the selected write
method before editing files or generating scripts. A generated script is not
an applied change; live execution remains subject to the applicable provider
and deployment contract.

## Project-local record

Keep generated documentation in the target project, not in the Crow package.
Use or create the following only when requested and authorized:

- `design/documentation-coverage.md`: inspected scope and evidence, excluded
  objects, limitations, conventions, affected-object counts, exceptions, and
  confirmation state.
- `design/documentation-findings.md`: append findings with object, evidence,
  impact, severity, and disposition; preserve prior findings.
- `design/documentation-session.md`: append session decisions, confirmations,
  apply choice, unresolved questions, skipped objects, and handoffs so work
  can resume without redrafting confirmed content.

Persist confirmed conventions in the target project's existing
`design/decisions.md` when present. Do not create a broader decisions register
without request. If the user pauses or declines a write, record the stopping
point and pending choice only when the user authorized project-local session
records.

Completion reports coverage and limitations, confirmed or explicitly skipped
drafts, findings and their dispositions, exact files/scripts changed, and
unresolved owner decisions. Stop when scope is ambiguous, evidence conflicts
with an approved decision, validation fails, or the request requires an
unreviewed live provider.
