# Single-route prompt

Replace bracketed fields with confirmed facts. Omit inapplicable fields;
keep material unknowns explicit. Add the selected client's invocation step
outside this prompt.

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
Stop before: [unapproved actions, changes outside scope, and review checkpoints].

Read the relevant evidence and owning skill first. Reuse confirmed answers
unless new evidence contradicts them. Resolve remaining material questions,
retain your own approvals and completion gates, and do not infer permission
for installation, external writes, or deployment from this prompt.
```

Explain what the selected role should return and what the developer should do
next. Do not claim that the prompt has been executed or its checks passed.
