# Design-smell catalog (testability)

Deeper catalog of design choices that make testing unnecessarily hard. Use during `discovery.md` scans when
the compact list there isn't enough. Each item is a candidate non-blocking finding for
`docs/testing/testability-notes.md` — flag, don't fix, unless asked.

## The one thing every entry has in common

Read this catalog through `foundation.md`'s **band-pass filter model**. Every smell here does the same
thing: **it forces a defect class to be caught at a later, more expensive filter than necessary.** The fix
always moves the defect earlier.

That displacement happens in one of two ways:

- **(a) The defect can't be caught at the filter that should catch it.** Hidden static state, a missing
  seam, or a god method makes the behavior unreachable from a unit test, so the defect escapes to
  integration, manual QA, or production.
- **(b) The defect is caught at an *earlier* filter than tests — so the test shouldn't need to exist.**
  Non-nullable types, exhaustive matching, and unrepresentable invalid states push the defect down to
  **filter stage zero, the compiler.** These are the highest-value fixes in the catalog: they don't make a
  test easier to write, they delete the test's reason to exist.

The biggest filter jump is usually the biggest win. Use that to rank findings — see
[`testability-improvements.md`](testability-improvements.md) for how to turn an entry here into a
prioritized, justified recommendation, and when *not* to recommend a change at all.

## Triage table

| Smell | Defect caught today at | Could be caught at | Rule |
|---|---|---|---|
| Nullable-but-required fields | Unit (or runtime) | **Compiler** | nullable analysis, `CA1062` |
| Primitive obsession | Unit, repeatedly per call site | **Compiler** | — |
| Illegal states representable | Unit, repeatedly per call site | **Compiler** | — |
| Non-exhaustive branching | Runtime (tests stay green) | **Compiler** (`CS8509`) | `CS8509` |
| Reference equality hiding value differences | Runtime / brittle unit assertions | **Compiler** (generated equality) | `CA1815` |
| Mutable state by default | Runtime (aliasing, concurrency) | **Compiler** (`init`, read-only) | `CA2227`, `CA1002` |
| Anemic domain model | Integration | Unit | — |
| Large impure functions mixing decision logic with I/O | Integration | Unit | — |
| God methods/classes | Integration | Unit | `S1200`, `S3776` |
| Missing seams at framework boundaries | Integration | Unit | — |
| Hidden static/global state | Integration, flakily | Unit | `S2223` |
| Long procedural methods | Unit, with many cases at once | Unit, few cases each | `S3776` |
| Boolean parameter soup | Unit, under-tested branches | Unit, named branches | `S107` |
| Partial functions and silent nulls | Runtime, at every call site | Unit, one explicit outcome | — |
| Exceptions as control flow | Unit, via brittle throw assertions | Unit, on a returned result | — |
| Untestable time/randomness | **Production** | Unit | — |
| Boundary enforced only by convention | Code review, intermittently | **Build** (architecture test) | — |
| Code predating a language feature that would enforce the rule | Unit (or runtime) | **Compiler** | — |

Where a real SonarQube/Microsoft rule exists it's noted for stronger justification when handing off; `—`
means no canonical rule ID exists for that smell, stated plainly rather than invented.

**The `Rule` column is also a scope boundary only when the matching analyzer is active.** Verify Roslyn
configuration and current SonarQube results before assuming a finding is already reported. Cite the rule if
you land on a covered smell, and spend dedicated discovery effort on rows the active toolset cannot raise.

For the full explanation of any one row — what the smell looks like, why it matters, and the preferred
alternative — see [`design-smell-entries.md`](design-smell-entries.md). Load it once you've landed on a
specific smell to write up; the triage table above is what a scan needs, the entries are what a finding
needs.
