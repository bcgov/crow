# Single-route prompt

Replace bracketed fields with confirmed facts. Omit inapplicable fields;
keep material unknowns explicit. Add the selected client's invocation step
outside this prompt. Fill both review checkpoints using the
[review policy](../modules/reviews.md); do not omit them as inapplicable fields.

```text
Use [verified agent name or the client's normal agent] with
[relevant installed skill identifiers] for this task:
[specific task and desired outcome].

Context: [repository/component and supplied evidence].
Confirmed decisions: [facts established in the interview].
Stage and allowed outputs: [advice/review/design/implementation; output scope].
Constraints: [behavior/contracts to preserve and relevant conventions].
Open decisions: [only unresolved material questions, or none].
Verification: [required evidence/checks, or ask the specialist to propose them].
Review/retry limit: [maximum correction/re-review cycles per checkpoint, then pause].
Stop before: [unapproved actions, changes outside scope, and review checkpoints].

Two review checkpoints:
1. Review [early artifact and focus] after [stage], before [dependent work].
2. Review [later/reconciled artifact and focus] after [stage], before final delivery.
At each checkpoint, obtain a bounded read-only review from a separate agent.
Verify available models and prefer a model family different from yours;
a different role name is not a different model family. Prefer distinct
reviewer families too when available. Honor current model/cost and delegation
policies; do not install tools or change models beyond authorized limits.
For a source-first review, give the reviewer the exact revision under review,
relevant evidence, constraints, and question, but not separate preliminary
findings, reasoning, or earlier review output. When the artifact itself is a
set of findings or recommendations, first give the reviewer its underlying
evidence and question; share the candidate synthesis only after the reviewer
returns an independent assessment. Use a fresh session or equivalent context
that excludes prior analysis where available; a separate role or session alone
does not establish fresh context. Disclose when prior conclusions were shared
or context isolation cannot be verified, and do not describe a potentially
primed review as blind.
Share only minimum permitted evidence, never secrets or personal data, and
honor data-handling/provider-approval policies; a prohibited route is unavailable.
If another family is unavailable or unverified, disclose this and use a
permitted separate same-family reviewer. If delegation is unavailable or
disallowed, supply a manual review prompt requesting the reviewer's verified
model family (or explicit unknown) and wait for returned findings.
Never count an unverified family as cross-family.
Do not count self-review or claim reviews that did not occur. If no separate
review is possible, pause and ask about explicitly reduced, unreviewed output.
You, the original agent, reconcile each review against evidence before
dependent work or final delivery: accept and apply justified in-scope fixes,
explain rejected findings, and surface unresolved decisions. Rerun affected
checks and obtain re-review for material changes within the review/retry limit;
pause on blockers or an exhausted limit. Return both review outcomes,
reconciliation decisions, remaining risks, and any family/capability limits.

Read the relevant evidence and owning skill first. Reuse confirmed answers
unless new evidence contradicts them. Resolve remaining material questions,
retain your own approvals and completion gates, and do not infer permission
for installation, external writes, or deployment from this prompt.
```

Explain what the selected role should return and what the developer should do
next. Do not claim that the prompt has been executed or its checks passed.
