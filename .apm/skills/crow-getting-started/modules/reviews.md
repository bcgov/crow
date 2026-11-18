# Two review checkpoints

Every generated task prompt includes two bounded, read-only reviews of the
proposed work, not reviews of Getting Started's prompt. The original task
agent (the coordinator for coordinated work) retains ownership and reconciles
each review before dependent work proceeds or results reach the user.
Getting Started only drafts these instructions; it never launches reviewers.

## Place reviews where they can change the outcome

Name the artifact, review focus, and point where work waits for each review.
Set a concrete correction/re-review limit per checkpoint and pause if it is
exhausted. Choose two meaningful checkpoints within the approved stage, for example:

| Task | First review | Second review |
|---|---|---|
| Approved implementation | Plan before edits | Tested changes before delivery |
| Architecture/design only | Proposed design before elaboration | Integrated architecture before delivery |
| Planning only | Approach and assumptions before detailed planning | Completed plan before delivery |
| Review/research/advice only | Evidence and preliminary synthesis | Final candidate findings or recommendations |

These are examples, not mandatory phases. Do not invent implementation for a
design-only request. If there is only one meaningful artifact, use an initial
candidate review and a second review of the reconciled candidate. The two
checkpoints do not replace required specialist checks or owner approvals.

## Select reviewers without inventing capabilities

At execution time, the original agent verifies available reviewer roles,
model selection, and underlying model families. Prefer a reviewer whose model
family differs from the original agent's at each checkpoint (for example,
GPT, Claude, or Gemini). A different specialist name on the same model family
does not provide this diversity. Prefer different families for the two
reviewers too when available; the same eligible family can serve both.
Never pin model IDs, prices, or a provider preference in Crow assets.

Honor the user's current model/cost, tool, delegation, data-handling, and
provider-approval policies. Share only the minimum permitted evidence;
never pass secrets or personal data to reviewers. If a provider cannot
receive the artifact under those policies, treat that route as unavailable.
Do not upgrade models, bypass restrictions, install tooling, or claim a
reviewer's family without evidence. If another family is unavailable or
cannot be verified, disclose that limitation and use a separate same-family
reviewer only when permitted. Do not label it cross-family.

When native delegation is unavailable or disallowed, supply a bounded manual
review prompt, identify the artifact/revision to review, request the reviewer's
verified model family (or an explicit unknown), and wait for the user to
return its findings. An unverified family never counts as cross-family.
Repeat at the second checkpoint. A separate reviewer
session can perform a manual review; the original agent's self-check cannot
count as either review. If neither route is possible, stop at the checkpoint
and ask whether to provide explicitly reduced, unreviewed output.

## Reconcile, then continue

Give each reviewer the relevant artifact/revision, evidence, constraints, and
specific review question. Reviewers return actionable findings with evidence,
not edits, approval, expanded scope, or unsolicited worker launches.

The original agent verifies each finding, resolves contradictions, and
records accepted changes, evidence-based rejections, and unresolved items.
Apply in-scope corrections and rerun affected checks; material changes must
be re-reviewed within the task's bounded review/retry limit. Ask for missing
decisions and pause when blockers remain or the retry limit is exhausted.

Before delivery, report both review outcomes and their reconciliation,
including family/capability limitations and remaining risks. Never present
raw reviewer output as the reconciled result or claim an unperformed review.
