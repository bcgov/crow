# Requirements interview

Inspect existing design artifacts and supplied requirements first. Ask whether
other documentation is available, such as data dictionaries, process maps,
requirements, ERDs, or catalogue entries. Cross-check supplied material against
repository evidence and record contradictions; do not silently prefer one
source.

Ask one focused question at a time. Capture decisions and unresolved items;
confirmed decisions should not be re-asked during a resumed session. Classify
unanswered items as:

- **Blocking** when they prevent a defensible grain, source map, security
  assumption, bus matrix, or acceptance criterion.
- **Advisory** when design can continue but an owner and impact must be
  recorded before implementation or deployment.
- **Deferred** when required evidence or a supported capability is
  unavailable; state the fallback and do not claim verification.

Cover these topics, adapting the order only when the user's scope requires it:

1. Outcome, consumers, scope, reporting questions, and success measures.
2. Facts, measures, candidate grain, history, and corrections.
3. Source systems, ownership, freshness, and evidence.
4. Dimensions, conformance, time handling, and the bus matrix.
5. Classification and security assumptions, report deliverable, navigation,
   and acceptance criteria.
6. Refresh cadence, expected volume, performance constraints, risks,
   decisions, glossary, and sign-off.

Stress-test each proposed grain with relevant counterexamples: multiple events
per entity, late corrections, multiple meaningful dates, duplicate source
keys, and backdated periods. Mark the grain provisional when evidence is
incomplete. Record volume, refresh, and performance assumptions as unknown
when not supplied.

## Dimensional design

State each fact's grain in business terms before proposing measures or
dimensions. A fact row represents one occurrence of that grain; do not combine
facts at different grains in one table. If requirements need multiple grains,
represent them as separate facts and map them separately.

Record each measure's meaning, unit, source, and whether it is additive across
time and other dimensions. Dimensions describe the context of facts. Identify
which dimensions are shared and conformed across facts, and show those
relationships in the bus matrix. Make history and late-correction behavior
explicit; do not assume a slowly changing dimension strategy or a particular
warehouse technology.

Confirm the delivery type as interactive, paginated, both, or another stated
format. When Power BI is selected, record whether the requested artifact is a
PBIX report, an RDL paginated report, or both. Confirm security and row-level
filtering assumptions separately from information classification; neither is
implied by the other.

The user must separately authorize repository writes and sign off the design.
If either is absent, keep artifacts as drafts and do not issue a signed-off
handoff.

## Design artifacts

When requested and write-authorized, keep work in
`docs/design/analytics/`:

- `requirements.md` for scope, users, questions, measures, delivery, and
  acceptance.
- `decisions.md` for confirmed decisions, sources, owners, and unresolved
  questions.
- `bus-matrix.md` for confirmed facts/grains and conformed or local
  dimensions.
- `glossary.md` for agreed business terms and definitions.
- `entity-map.md` for source entities, evidence, relationships, and
  confidence.
- `session-state.md` for the last completed interview topic, confirmations,
  pending questions, and resume point.

Preserve existing files and prior confirmed history. Do not create these
artifacts when the user requests advice only.
