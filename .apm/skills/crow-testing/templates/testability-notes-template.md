# Testability Notes

<!--
Non-blocking findings from discovery/implementation passes -- for handoff to another agent or developer,
not to be fixed as part of a testing engagement itself unless explicitly requested.
-->

## Business terminology clarified

<!-- Homework/discussion findings -- record here so clarifications don't live only in chat history. -->

| Term | Clarified meaning | Where it came from |
|---|---|---|
| | | |

## Low-hanging fruit

<!-- Easy-to-test, commonly-missed, high-defect-risk areas. -->

| Area | Why it's low-hanging fruit | Suggested test level |
|---|---|---|
| | | |

## Design issues affecting testability

<!-- E.g. nullable-but-required fields, primitive obsession, hidden static state -- see
     modules/reference/design-smell-catalog.md for the fuller catalog used to find these, and
     modules/reference/testability-improvements.md for how the filter stage and priority are decided.
     "Recorded at" lets a later engagement notice a finding whose cost/priority depended on the TFM at
     discovery time -- e.g. a fix that needed a backport package may become a built-in after a migration. -->

| Location | Issue | Simpler alternative | Defect caught today at | Filter it moves to | Priority | Impact if unaddressed | Recorded at (TFM / LangVersion) |
|---|---|---|---|---|---|---|---|
| | | | | | | | |

## Accepted constraints and decisions

<!-- Findings that will NOT be actioned, and why. Record these so the same proposal isn't re-raised on the
     next engagement. Common causes: a UI framework requires two-way binding, the ORM requires mutable
     navigation collections, the target framework predates the feature, or the user simply decided against
     it. A constraint is not a smell.

     "Recorded at" matters most here: if the reason mentions the target framework or language version (e.g.
     "not available until net8.0", "requires C# 11"), a later engagement can compare it against the
     project's *current* TFM/LangVersion and flag it as possibly stale during discovery. -->

| Finding | Why it can't change | Decided by | Date | Recorded at (TFM / LangVersion) |
|---|---|---|---|---|
| | | | | |

## Candidates for testing

<!-- Ranked list of areas worth testing next, grouped by feature/module, most valuable first. -->

| Area | Why it matters | Test level |
|---|---|---|
| | | |
