# [Action or outcome a tester recognizes] (MC-XXX)

<!--
One authoritative, business-readable manual check (or related checks with application/page variants).
QA execution results belong outside the repository. Omit inapplicable technical fields.
Do not invent setup conditions or expected behavior: get reviewer approval when uncertain.
Write the tester-facing sections as instructions for a person using the application, not
as code, API requests, database queries, or test-framework steps. Use verified on-screen
labels and menu names; if they are unknown, resolve them rather than guessing.
-->

## What this checks

[One or two plain-language sentences describing the behavior and scope.]

## Before you start

- Use [application] in an approved non-production test environment.
- Sign in as [user role or permission in plain language; state if no sign-in is needed].
- Open [page] by selecting [visible menu items or links that lead there].
- Find [a recognizable test record with the required status, dates, relationships, or other
  relevant state]. If it must be created or changed first, say exactly how, or name the
  person/team who will provide it. Use synthetic/non-sensitive test data.
- [External dependency or alternate account, if required.]

## Steps (MC-XXX-01)

1. [Choose a visible button, link, field, or menu item by its on-screen name.]
2. [Enter or select the exact test value needed; continue with the next visible action.]

## Expected result

[What the tester can see on the page after these steps. Include an intermediate result beside
the relevant step if it matters. Include save/reopen only when persistence is in scope.]

---

## Technical details

| Field | Value |
|---|---|
| Manual QA area ID | `MC-XXX` |
| Manual QA index | Link to `docs/testing/manual-coverage.md` with the correct relative path |
| Status | Draft / Needs decision (omit when current) |
| Work item | [ID/link when applicable] |
| Page / route | [Actual relative route when applicable] |
| Source components | [Paths when useful] |
| Classification | Manual-only / Deferred automation: [brief reason] |
| Related automated checks / known gap | [Test file/folder link or omit] |
| Recheck when | [User-facing feature or shared control that changes; match the index] |
| Representative pages | [For shared UI controls only: chosen pages and why they represent the change] |

<!--
Scenario IDs belong on the individual check: in the Steps heading for a single check, in each Checks
table row for multiple short checks, or in each separate multi-step heading. Never list only the first
scenario ID in the shared Technical details table.

For multiple short, independent checks sharing the same setup, use this form instead of the
single Steps/Expected result pair (each row has its own stable, unique scenario ID):

## Checks

| ID | What to do | What you should see |
|---|---|---|
| MC-XXX-01 | [On-screen action] | [Visible outcome] |
| MC-XXX-02 | [Other on-screen action] | [Other visible outcome] |

For a check requiring several actions, use a separate numbered Steps and Expected result
subsection headed with its own scenario ID instead of compressing actions into a table cell.
When checks have different setup or starting pages, give each its own "Before you start".
When one check has app/page variants, name each variant and its expected result explicitly.
For shared UI controls, state representative pages and why they were chosen under Technical details.
-->
