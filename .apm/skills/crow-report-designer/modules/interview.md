# Nine-phase interview contract

## Model guidance

Crow agents have no per-agent model pin. Model changes are recommendations, never automatic settings:

- **Lightweight:** record confirmed phase answers, populate `spec.md`/`decisions.md`/`glossary.md` from
  already-agreed content, and re-ask only due staleness checks.
- **Mid-tier:** run the phase-by-phase interview, reconcile grain/source evidence, resolve the PBIX/RDL
  deliverable classification, and facilitate contradiction/decision resolution.
- **Premium:** use only when the bus matrix or security model has conflicting stakeholder requirements that a
  mid-tier pass cannot reconcile, or when external-documentation intake surfaces a hard contradiction with
  repository evidence.

When practical, use a different model family to review a signed-off handoff payload against the interview
record before scaffolding or build generation begins. If the environment cannot switch models easily, record
the recommendation and proceed.

Inspect existing design artifacts read-only, then ask for explicit write
authorization before creating or updating any `design/` file. Run phases in
order and do not build before confirmation:

1. scope, users, outcome; 2. reporting questions and measures; 3. fact grain and history; 4. source systems and freshness; 5. filters, time, and navigation; 6. dimensions, conformance, and bus matrix; 7. security/RLS, environments, and operational constraints; 8. visual/report delivery, debug/data-freshness expectations, and acceptance; 9. refresh/performance, risks, decisions, glossary, and sign-off.

Before Phase 1, ask once whether existing documentation (data dictionaries,
process maps, requirements documents, wiki pages, or ERDs) is available.
Extract facts from anything supplied, cross-check them against repository
evidence, cite the source in `design/decisions.md`, and surface contradictions
instead of silently preferring one source.

In Phase 8, classify the deliverable as `pbix`, `rdl`, or `both`. Signals for
`rdl` (Power BI Report Builder deployed to PBIRS, not a `.pbix`): print/PDF or
pixel-perfect layout, mail-merge or document-style output, large tabular
exports, or data-driven per-entity subscriptions. Confirm the classification
with the user and record it in `spec.md` and the handoff payload.

Capture decisions and unresolved questions in `design/decisions.md`; add agreed terms to `design/glossary.md`. The minimum signed-off set is `spec.md`, `decisions.md`, `bus-matrix.md`, `glossary.md`, and `entity-map.md` (with unavailable evidence marked). Phase 9 must include refresh cadence, expected volume/batch-sizing assumptions, performance constraints, and `architect_notes` for upstream-first design or partition decisions. Each phase ends with a user confirmation or an explicit deferred item with owner and impact. A contradiction reopens the affected phase. Repository write authorization and specification sign-off are separate gates.
