# [Feature Name] Scenarios

<!--
Fill in following a plain-language, table-first pattern:
- Tables first, prose only where a table would lose meaning.
- This document is a living artifact: keep it current as implementation progresses, don't just write it
  once at the start.
-->
## Scope

<!-- What is being tested, and what is explicitly out of scope. -->

## Terminology

<!-- Any business/domain terms that weren't obvious up front, defined in plain language. Add to this as new
     terminology is clarified during implementation -- don't leave it only in chat history. -->

## Authoritative rules

<!-- The business rules under test, in plain language, as a bullet list or short prose. This is the
     "acceptance criteria" a reader should be able to verify the Scenarios table against. -->

## Scenarios

| ID | Operation / setup | Seeded data | Expected result | Additional assertions |
|---|---|---|---|---|
| S1 | | | | |

## Required assertions

| Area | Assertion |
|---|---|
| | |

## Conditional external dependency scenarios

Use this table only when the feature has a shared/canonical service, external
decision source, event contract, or digital proof. Mark non-applicable rows
`N/A` rather than inventing behavior.

| Scenario | Required assertion |
|---|---|
| Upstream outage / timeout | No false success; bounded wait and visible recovery or assisted path |
| Stale canonical data | Freshness is represented and stale data is not presented as current |
| Invalid / expired / revoked / replayed proof | Decision is denied or held according to approved behavior |
| Duplicate event | Processing is idempotent and side effects are not duplicated |
| Retry exhaustion / cancellation | Work stops or is queued according to contract and remains observable |
| Fallback / audit | Fallback preserves authorization, assurance, minimization, and available audit/provenance |

## Status

<!-- Keep this section current every phase. -->

| Phase | Scope | Status | Notes |
|---|---|---|---|
| 1 | | Not started / In progress / Done | |

**Remaining work:** <!-- what's left, in plain language -->

**Unusual decisions:** <!-- anything a future reader would be surprised by, and why it was decided that way -->
