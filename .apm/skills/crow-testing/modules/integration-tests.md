# Integration tests (generic)

Stack-agnostic scoping and workflow. Load a `dotnet/integration-tests.md`-style module for stack-specific
detail.

## When to write an integration test (scoping criteria)

Write one only when a feature both matches one or more of the signals below **and** genuinely needs a real
external boundary (DB, HTTP, another service) to be exercised correctly — check `unit-tests.md`'s scoping
check first; a state machine or combinatorial rule that only touches in-memory objects is still a unit test.

- State machines / multi-step workflows where the outcome depends on a sequence of prior state.
- Combinatorial business rules or permission/role combinations impractical to eyeball manually.
- Date/schedule math (recurring schedules, business-day/holiday rules, timezone edge cases).
- Complex calculations spanning multiple entities/queries where the right answer needs a separately
  computed oracle value.
- Data merge/migration logic, where a bug silently corrupts real data.

Do **not** default to an integration test for simple CRUD with no branching logic, or for validation already
covered by a unit test — those stay in `unit-tests.md`.

## Scenario-doc-first workflow (hard gate)

For every integration test area (and any complex/critical unit-test area per `unit-tests.md`):

1. **Write the scenarios document first**, using `templates/scenario-doc-template.md`: plain language, a
   Scope section, an Authoritative Rules section, a Scenarios table (ID / setup / seeded data / expected
   result / extra assertions), and a Required Assertions table. Summarize into tables; push details into
   prose only where a table would lose meaning.
2. If the user hands you a partial rule set or a single implemented feature, offer to expand it into a
   complete scenario set covering the full acceptance criteria.
3. **Get explicit user review/approval of the scenarios doc before writing any test code.** This is a hard
   gate — do not start implementation on the strength of an assumed-correct scenario list. If the user
   disputes a scenario or rule, revise the doc and re-present it rather than proceeding on the disputed
   version; if the user asks to skip the gate entirely, decline for genuinely integration-shaped or
   business-critical work and say why — the gate exists to catch misunderstood rules before code is written,
   not to slow down simple cases (which shouldn't have reached this workflow in the first place, per the
   scoping criteria above).
4. **Implement in phases** after approval. After each phase, update the scenario doc: what's implemented,
   what remains, any unusual decisions made along the way, and any terminology that was clarified but wasn't
   obvious up front. The scenario doc should always reflect current reality, not just the original plan.
5. Update `docs/testing/testing-plan.md` to reflect the feature's status once a phase completes.
