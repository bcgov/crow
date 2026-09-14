# Work-item candidate drafting

Load when the agent identifies a confirmed bug or an actionable design smell that should be tracked as
work. It supports draft-only output and user-confirmed manual filing; automated tracker creation is a future
capability.

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
- `Created — <provider>:<ID>` — a declared write-capable provider created the item and returned an ID/link.
- `Declined / Won't track` — the user explicitly rejected the candidate.

When the user files a draft manually, keep `Draft — not filed` until the user confirms filing succeeded and
supplies the resulting ID/link. Then update the index to `Existing — <ID/link>` and delete the local draft only
after the reference is persisted. If filing is uncertain, leave the draft and status unchanged.

The agent may reference a user-supplied ID or link, but must not validate or search for it. Automated creation
requires a declared write-capable provider and explicit per-item authorization.

## Plain-language draft format

Store the full candidate in `docs/testing/drafts/<key>-<short-slug>.md` and present the same text to the user.
Keep the subject and summary understandable without technical background. Put implementation details below
the summary. The draft is durable while it is unfiled or while filing/creation is unconfirmed.

Drafts are public repository content. Include only safe, sanitized descriptors: never persist credentials,
tokens, personal information, private URLs or hostnames, raw request/response payloads, transcripts, or
unredacted logs/screenshots. Replace sensitive values with placeholders and point to approved secure evidence
storage when more detail is needed.

### Bug candidate

```markdown
# <Subject>

- **Draft key:** DRAFT-BUG-XX
- **Type:** Bug
- **Tracking:** Draft — not filed | Existing — <ID/link> | Created — <provider>:<ID> | Declined / Won't track

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
- **Tracking:** Draft — not filed | Existing — <ID/link> | Created — <provider>:<ID> | Declined / Won't track
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

## Filing and cleanup

### Manual filing

1. Present the draft and tell the user to copy it into Azure DevOps Server.
2. Keep the draft and `testing-plan.md` row unchanged while the user files it.
3. After the user confirms success and provides the ID/link, update the row to `Existing — <ID/link>`.
4. Delete the local draft only after the updated index is saved successfully.

### Automated creation

1. Show the final subject/body and target project.
2. Obtain explicit authorization for this specific item.
3. Create the item through the declared write-capable provider.
4. Verify the returned ID/link, persist `Created — <provider>:<ID>`, then delete the draft.
5. On any failure or uncertainty, retain the draft and report the unresolved state.

## Future boundary

Direct creation is not available in the current phase. No search, simulation, or claim of external creation is
permitted without the declared provider, authorization, returned reference, and persistence confirmation.
