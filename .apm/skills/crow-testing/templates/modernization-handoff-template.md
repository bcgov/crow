# Modernization / Design Finding: [Short Name]

<!--
Use this instead of a testability-notes.md row when a finding is cross-cutting (a habit or convention
across many files, not one location) or the user asked for a fuller writeup before deciding. See
modules/reference/testability-improvements.md § Handing off.

crow-testing documents; it does not fix, refactor, or modernize. This file is written so whoever does that
work next doesn't have to re-derive the context.
-->

## Scope

<!-- What was found, and why it graduated to its own document instead of a testability-notes.md row
     (cross-cutting habit, or the user asked for more detail). One or two sentences. -->

**Recorded against:** <!-- TFM / LangVersion at the time this was written, e.g. "net8.0 / C# 12". This lets a
later discovery engagement notice the project has moved past what this finding assumed. -->

## Findings

<!-- One row per distinct pattern. Reuses the five-part finding shape from testability-improvements.md at a
     larger grain: current shape, recommended shape, why it matters for testing, the rule/reference if one
     exists, the filter stage the fix would move the defect to, and priority. -->

| Pattern | Current shape | Recommended shape | Why (testability lens) | Rule / reference | Filter stage moved to | Priority | Representative locations |
|---|---|---|---|---|---|---|---|
| | | | | | | | |

## Who could help

<!--
Suggested, never required. crow-testing does not invoke any of these -- it only names a candidate when one
genuinely fits, so the user isn't starting from nothing.

- If this repository or organization already has a dedicated modernization/tech-debt agent, hand it there
  first.
- Otherwise, consider naming a candidate for the user to evaluate -- for example, for .NET/C#: a broad,
  stack-agnostic modernization agent, or a narrower .NET-specific upgrade/cleanup agent, if either is
  available in the user's tooling.
- Or: a developer picking this up manually as a scheduled cleanup pass.

State which applies here, and why, in a sentence or two -- don't just list options.
-->

## Status

<!-- Keep current as this is revisited. Mirrors the scenario doc's Status section so a later reader (or
     re-engagement) doesn't have to re-derive context. -->

| Date | What happened | Decided by |
|---|---|---|
| | | |

**Remaining work:** <!-- what's still open, in plain language -->

**Decisions and terminology clarified:** <!-- anything a future reader would be surprised by, including any
business/domain terms clarified while investigating this finding -->
