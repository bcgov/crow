# Coordinated prompts for complex work

Load when requested explicitly, or when outputs, shared decisions, or
cross-domain changes need several specialists. File count, a long brief, or
a desire for thoroughness alone does not justify delegation.

Getting Started drafts a prompt for the next coordinator session. It does
not become the coordinator, launch workers, execute a plan, create a DAG
manifest, or maintain a new workflow engine.

## Interview the orchestration boundary

Propose a small decomposition and confirm only unresolved choices:

- **Objective and stage:** discovery/design/review only, or implementation
  after approval? What is the stop point? A later implementation instruction
  starts a new approved stage; it does not erase earlier constraints.
- **Sources and targets:** repositories, documents, baseline behavior,
  replacement stack, and approved non-production environments. Identify
  authoritative decisions and label unevidenced requirements.
- **Preservation versus redesign:** which APIs, business rules, schemas,
  stored data, or UX must remain unchanged? Do not choose the
  [legacy-modernization](../../crow-legacy-modernization/SKILL.md) preservation
  workflow for an unapproved datastore or contract redesign.
- **Coordinator and specialists:** use an existing coordinator only when its
  boundary fits; otherwise prompt the client's normal agent to coordinate
  the selected existing Crow specialists/skills. Do not invent a Crow
  orchestration agent or assume an application-development agent exists.
- **Approvals and reviews:** who decides material trade-offs, what requires a
  manual review, and are additional reviews needed beyond the
  [two required checkpoints](reviews.md)?
  Honor the user's model/cost policy; do not pin models in Crow assets.

## Prompt contract

Use the
[orchestration template](../resources/orchestration-prompt-template.md).
Expand only sections relevant to the confirmed task. Include:

1. Confirmed objective, stage, sources, constraints, open decisions, and
   expected final deliverables.
2. A bounded assignment for each selected specialist: exact installed
   name/skill, input references and revisions, owning repository, declared
   read/write paths, required output, prerequisite, verification, and stop.
3. A dependency order. Evidence workers may run concurrently if independent;
   consumers wait for verified prerequisites and required sign-off. Parallel
   sessions are not permission for concurrent writers to shared files.
4. One owner per output/shared contract. The coordinator reconciles findings
   and changes to authoritative decisions before consumers proceed. Workers
   report cross-scope issues rather than editing another owner's output.
   Each repository keeps the outputs defined by its owning skill; resolve
   fixed-path collisions before assigning two writers.
5. Two task-appropriate review checkpoints using the
   [review policy](reviews.md), with the original coordinator reconciling
   each review before dependent work or final delivery. Preserve additional
   specialist checks, verification, and owner approvals; a second model or
   coordinator cannot grant owner approval or waive a specialist gate.
6. Resume behavior: reuse recorded decisions and affected outputs, refresh
   stale evidence, carry blockers forward, and reopen dependent work when
   assumptions change. Do not repeat the entire interview on every handoff.
7. Host-capability fallback. Prefer existing native workers/subchats where
   supported; otherwise stage the same prompts manually/sequentially.
   Give workers a terminal deliverable and bounded review/retry limits.
   The coordinator issues affected follow-ups after consolidating evidence;
   do not let workers enter unsolicited peer-update loops. Pause when a
   limit is exhausted rather than weakening acceptance checks.

Follow the existing
[interaction contracts](../../crow-agent-skill-authoring/modules/interaction-contracts.md)
for document authority, evidence confidence, signed-off handoffs where an
owning workflow requires them, and truthful completion. Do not author a new
handoff schema, duplicate specialist ledgers, or embed a specialist's full
procedure in the orchestration prompt.

## Illustrative decompositions

These are conditional role sketches, not fixed pipelines. Link the selected
assets from [task-routing.md](task-routing.md) and preserve their boundaries.

### Re-platforming an application

Parallel read-only evidence assignments can inspect legacy architecture and
reuse, enforced rules/requirements, and UI constraints. A solution-design
owner reconciles those results and confirmed target constraints. Data,
API/implementation, CI, and UX specialists own the applicable proposals;
dependent outputs wait for shared project/API/model decisions.

For a design-only request, permitted writes are only the declared design
outputs/prototype, not application implementation or environment activation.
Review the integrated architecture/security and implementation task list
before seeking implementation approval. Subsequent approved slices get
targeted tests and the two review checkpoints. Unknown baseline
coverage is a gap, not proof of equivalence.

### Security scanning and remediation

Establish per-application scope and current architecture inputs first.
Independent architecture/security evidence can be gathered concurrently when
their declared outputs do not overlap. The security review owns applicable
scans and its findings/synthesis; the coordinator must not schedule a second
scan merely because another role uses the same skill.

Remediation starts only with the required current inputs and approved scope,
and verifies each finding in source before editing. Assign disjoint fixes
only when contracts and files do not overlap. Required test evidence and
re-review follow the edits. Ticket writes, installations, production access,
and deployment are separate decisions, not implicit remediation permission.

### Coordinated data-model changes

The data architecture owner identifies schema/storage changes, affected
consumers, governance metadata, migration ordering, and rollback. Obtain the
applicable owner approvals before dependent changes. Application workers
coordinate ORM, API, and consumer contracts against that agreed model;
testing verifies real engine/migration and persistence behavior as applicable.
CI/deployment proposals depend on the approved migration and rollback plan.

A legacy-modernization data-change handoff, when required by that workflow,
must be validated and signed off before its consumer acts. Do not silently
move datastore changes into a preservation-only modernization assignment.
Never apply a migration to a shared/production database from a generated
prompt without the separate required authorization.
