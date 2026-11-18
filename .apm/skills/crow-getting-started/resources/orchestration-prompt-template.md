# Coordinated-task prompt

Tailor this contract to the confirmed task. Use exact discoverable agent
names/skill identifiers, not placeholder roles as invented agent names.
The coordinator is the next session's role; Getting Started does not execute
this prompt. Omit irrelevant phases and unresolved implementation permission.
Keep both review checkpoints, tailored using the
[review policy](../modules/reviews.md).

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
Review/retry limits: [maximum correction/re-review cycles per checkpoint, then pause].
Pause when exhausted; never weaken a verifier to make a phase pass.

Gates:
[Evidence/design confirmation and applicable owner approvals.]
[Plan/task-list review and explicit implementation authorization.]
[Approved implementation slices, applicable tests, integrated security/code review.]
[Separate manual review, provider/ticket writes, migration and deployment approvals.]
Approval for planning is not approval to build; approval for one phase does
not authorize the next. Use signed-off handoffs only where the owning workflow
requires them. Never bypass specialist scope or approval gates.

Two review checkpoints:
1. Review [early artifact and focus] after [stage], before [dependent work].
2. Review [later/reconciled artifact and focus] after [stage], before final delivery.
At each checkpoint, obtain a bounded read-only review from a separate agent.
Verify available models and prefer a model family different from yours;
a different role name is not a different model family. Prefer distinct
reviewer families too when available. Honor current model/cost and delegation
policies; do not install tools or change models beyond authorized limits.
Share only minimum permitted evidence, never secrets or personal data, and
honor data-handling/provider-approval policies; a prohibited route is unavailable.
If another family is unavailable or unverified, disclose this and use a
permitted separate same-family reviewer. If delegation is unavailable or
disallowed, supply a manual review prompt requesting the reviewer's verified
model family (or explicit unknown) and wait for returned findings.
Never count an unverified family as cross-family.
Do not count self-review or claim reviews that did not occur. If no separate
review is possible, pause and ask about explicitly reduced, unreviewed output.
You, the original coordinator, reconcile each review against evidence before
dependent work or final delivery: accept and apply justified in-scope fixes,
explain rejected findings, and surface unresolved decisions. Rerun affected
checks and obtain re-review for material changes within the review/retry limit;
pause on blockers or an exhausted limit. Return both review outcomes,
reconciliation decisions, remaining risks, and any family/capability limits.

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
