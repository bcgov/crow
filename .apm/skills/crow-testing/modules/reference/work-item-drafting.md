# Work-item candidate drafting

Load when the agent identifies a confirmed bug or an actionable design smell that should be tracked as
work. This module produces a draft candidate; it does not search or create items in an external tracker.

## When to draft

Draft only when:

- a confirmed bug contradicts an authoritative rule, documented expectation, or test that should pass; or
- a design smell directly blocks automated test authoring, requires an architectural seam/refactor, and the
  user has explicitly agreed that it should be tracked as backlog work.

Keep ordinary testability notes and cross-cutting modernization findings in their existing artifacts.
Do not create a work-item candidate for every improvement suggestion.

Before creating a new candidate, inspect the local `testing-plan.md` **Work-item candidates** index for a
matching key or subject. This is the only duplicate check in this phase.

## Candidate identity and status

Use a stable local key such as `DRAFT-BUG-01` or `DRAFT-SMELL-01`. Increment from the existing local
index; do not reuse a key or fabricate an external work-item ID.

Use exactly one tracking value:

- `Draft — not filed` — this repository contains a proposed item; no external item was created.
- `Existing — <ID/link>` — the user supplied an existing work-item ID or link.
- `Declined / Won't track` — the user explicitly rejected the candidate.

The agent may reference a user-supplied ID or link, but must not validate, search for, or create it.

## Plain-language draft format

Store the full candidate in `docs/testing/drafts/<key>-<short-slug>.md` and present the same text to the user.
Keep the subject and summary understandable without technical background. Put implementation details below
the summary.

### Bug candidate

```markdown
# <Subject>

- **Draft key:** DRAFT-BUG-XX
- **Type:** Bug
- **Tracking:** Draft — not filed | Existing — <ID/link> | Declined / Won't track

## Summary

<What is wrong, when it happens, and who or what is affected.>

## Details for developers and agents

- **Reproduction steps:** ...
- **Affected component/files:** ...
- **Related scenario/test/commit:** ...
- **Likely cause:** ... (only when supported by evidence)
- **Impact/priority:** ... (use only evidence-supported wording)
- **Workaround:** ...

## Manual verification after the fix

1. ...
2. ...

**Expected result:** ...
```

### Design-smell candidate

```markdown
# <Subject>

- **Draft key:** DRAFT-SMELL-XX
- **Type:** Design smell
- **Tracking:** Draft — not filed | Existing — <ID/link> | Declined / Won't track
- **Behavior change:** None expected | Approved change: <plain-language description>

## Summary

<What makes the code harder to test, change, or understand, and why it matters.>

## Details for developers and agents

- **Affected component/files:** ...
- **Evidence:** ...
- **Proposed refactor/seam:** ...
- **Related testability note/scenario/test:** ...
- **Impact/priority:** ... (use only evidence-supported wording)

## Verification criteria

- ...

## Manual happy-path check

Include this focused section when the refactor affects a user-facing path or cannot be fully automated.

1. ...
2. ...

**Expected result:** Existing user-facing behavior still works as described.
```

For an internal-only smell that is fully verified by automated tests, state that the manual happy-path
section is not applicable and explain why in one sentence. Never invent user-facing steps.

## Future boundary

Direct creation may be considered later with a declared write-capable provider and explicit per-item user
authorization after the final text is shown. This phase never creates, simulates, or claims to create an
external work item.
