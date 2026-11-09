# Example Mapping and predict-then-verify

Load for Step 5 scenario work, Step 7 bug regressions, and characterization work that uses
predict-then-verify. Skip for simple unit work (Step 6).

## Example Mapping with the user

Agree on rules and concrete examples with reviewers before writing tests, so prose ambiguity is resolved
early. The agent drafts from available evidence; the humans correct.

| Card | Scenario-doc home |
|---|---|
| Rule | `Rules` (R#), one plain-language rule per row |
| Example | `Test matrix` row (S#): a business example and its expected outcome |
| Question | `Open questions` (Q#) for anything the code and docs do not settle |

1. Draft rules with a source for each. Do not invent rules.
   - Greenfield (feature not built): use the story, acceptance criteria, and stakeholders; ask rather than
     draft when they are thin.
   - Brownfield (feature exists): also use code, docs, and existing tests. Mark code-only behavior the
     requester is unsure about as "not confirmed".
2. For each rule, add examples with real values: a typical case, each boundary, each failure. Pair examples
   that differ by one input so the tested rule is obvious.
3. Anything you cannot derive is a question, not an assumption. Ask the most blocking one first.
4. Ask reviewers: "What example would break this rule?" and "Is there a rule these examples miss?"

### Write for a business reader

- Use familiar business words. Avoid code and test setup.
- Keep sentences short. Put one idea in each sentence.
- For several actions, use numbered steps. Put one action in each step.
- State the exact result, including amounts, dates, or status.
- Define unfamiliar business terms under `Terms`.

**Matrix example:** The order is $100.00. The customer enters SAVE10. No discount applies. The order must
be over $100.

Use `Example detail` only when a calculation, boundary, or disputed outcome needs more than a matrix cell.
Keep each action brief. Include all relevant boundary and failure cases. Add one short reason when useful.

Time-box the session (about 25 minutes of reviewer time per story). Then read the shape of the map:

| Signal | Meaning | Action |
|---|---|---|
| Many open questions | Not ready | Resolve questions affecting in-scope behavior, or exclude that behavior from approval |
| Many rules | Story is too big | Propose splitting the feature |
| Many examples under one rule | Rule is too complex | Split the rule |
| Few rules, few examples, no questions | Ready, or too vague | Ask "what would break this?" once more |

Approve only when every in-scope rule has a row, every row names a rule, and no unresolved question affects
an approved expected outcome. A Q# records uncertainty; it does not resolve it. A rule marked "not
confirmed" needs a reviewer decision before approval. A question may remain deferred only if the affected
rules and scenarios are explicitly excluded from the approved scope. Group matrix rows by rule and order
them simplest first within each rule; that order is the test list.

## Predict, then verify

Before running a new or changed test, state the predicted outcome and why, in chat. Record it in the scenario
doc only when a mismatch teaches something future readers need (`Prediction mismatches`).

- New behavior: Red with the exact expected failure, for example `expected 404, got 200 because the
  endpoint does not check ownership yet`. A compile error is not a useful red; fix the test until it fails on
  the assertion. Then see § Red tests and hand-off.
- Existing behavior (characterization, or tests added after the code): predict Pass and why. Only if you
  doubt the test can fail, change the test's expected value and confirm it fails; never edit production code.
- Bug regression: predict the exact symptom from the report before the fix, then Pass after.

Run one scenario per cycle and compare:

| Result | Meaning | Action |
|---|---|---|
| Matches | Understanding is in sync | Continue |
| Fails differently | Misread code, wrong setup, or different bug | Stop, diagnose, ask if the rule is in doubt |
| Passes unexpectedly | Hollow test, behavior already exists, or wrong setup | Stop, strengthen the test or reclassify |
| Fails when Pass predicted | Defect or wrong rule | Stop, report as a finding; never edit the test to pass |

## Red tests and hand-off

The agent writes tests only; it never makes them green by changing production code.

1. Commit red tests only to a separate feature branch, never the default branch, so developers have time
   to implement before merge.
2. Before merge, any test for a behavior that is still not implemented uses a skip mechanism supported by
   the target framework and version; follow its specific guidance (for .NET/xUnit, see
   [`test-code-guidance.md`](../dotnet/test-code-guidance.md)). The skip reason names the scenario
   (for example, `S4 - not implemented`), and its Coverage reads `Not implemented - no verification claim`.
3. Ask who makes the tests pass: the developer (default), or another agent only when the user explicitly
   authorizes that hand-off.
4. When told the code is ready, enable skipped tests for the confirming run. Leave passing tests enabled and
   mark them `Automated`; if the implementation is still deferred, keep them skipped and mark them
   `Not implemented - no verification claim`. Report failures without claiming coverage. Update the status
   rollup.

## Optional pause points

For complex or critical work, ask once at Step 2 whether to pause after Red (before hand-off) or after the
confirming run (before docs are updated), or neither. At a pause, show predicted versus actual and the next
scenario, then wait. Keep the choice in chat; add it to the doc only if the user wants it recorded.
