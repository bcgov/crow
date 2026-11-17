# Coordinated-task prompt

Tailor this contract to the confirmed task. Use exact discoverable agent
names/skill identifiers, not placeholder roles as invented agent names.
The coordinator is the next session's role; Getting Started does not execute
this prompt. Omit irrelevant phases and unresolved implementation permission.

```text
Act as coordinator for [objective and final deliverables].
Current stage: [discovery/design/review only OR explicitly approved implementation].
Stop point: [review-ready outputs, approval checkpoint, or verified approved scope].

Sources and target repositories: [bounded references and authoritative documents].
Confirmed requirements and decisions: [include the interview's confirmed facts].
Preserve: [contracts, behavior, data, UX, and other fixed boundaries].
Separately scoped changes: [approved redesigns; name missing approvals explicitly].
Open decisions and prerequisites: [owners, missing inputs/tools/targets, or none].

Start by verifying this scope and the available client capabilities.
Use native specialist workers/subchats only where supported and authorized.
Otherwise propose the same assignments as manual/sequential sessions using
the relevant installed Crow skills. Do not invent a dispatcher or install one.
Honor the user's current model, cost, and delegation policy.

Assignments:
- [ID]: [exact installed agent/skill and bounded objective].
  Inputs/revision: [verified evidence or upstream output].
  Repository and output owner: [one responsible worker/role].
  Allowed reads/writes: [declared paths; read-only when not approved].
  Deliverable: [existing owning skill's output contract].
  Depends on: [assignment IDs, verified outputs and required approvals].
  Verify/stop: [acceptance evidence and unresolved decision boundary].
[Repeat only for necessary specialists.]

Order and parallelism:
[Independent evidence assignments may run in parallel.]
[Named join/checkpoint before dependent design or implementation.]
Keep a single writer for each shared file/contract. Do not let workers edit
another owner's outputs. Reconcile contradictions and shared decisions before
dependent work continues. Stop consumers on failed/stale prerequisites.
Workers stop at their assigned deliverable; the coordinator consolidates
results and issues only necessary affected follow-ups.
Review/retry limits: [bounded limits appropriate to this task].
Pause when exhausted; never weaken a verifier to make a phase pass.

Gates:
[Evidence/design confirmation and requested independent review.]
[Plan/task-list review and explicit implementation authorization.]
[Approved implementation slices, applicable tests, integrated security/code review.]
[Separate manual review, provider/ticket writes, migration and deployment approvals.]
Approval for planning is not approval to build; approval for one phase does
not authorize the next. Use signed-off handoffs only where the owning workflow
requires them. Never bypass specialist scope or approval gates.

Continue within approved scope until the stop point, except when a material
decision, approval, missing prerequisite, unsafe target or failed check blocks
correct work. Report blockers rather than treating them as success.
Reuse confirmed decisions on resume, refresh affected evidence, and reopen
dependent phases when a shared assumption changes.

Return one integrated status with delivered outputs, source/check evidence,
resolved contradictions, residual gaps and the next required user action.
Do not claim tests, scans, independent reviews, equivalence, manual QA,
deployment, or another worker's acceptance unless actually verified.
```
