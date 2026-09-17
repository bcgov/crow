# Nine-phase interview contract

Inspect existing design artifacts read-only, then ask for explicit write
authorization before creating or updating any `design/` file. Run phases in
order and do not build before confirmation:

1. scope, users, outcome; 2. reporting questions and measures; 3. fact grain and history; 4. source systems and freshness; 5. filters, time, and navigation; 6. dimensions, conformance, and bus matrix; 7. security/RLS, environments, and operational constraints; 8. visual/report delivery, debug/data-freshness expectations, and acceptance; 9. refresh/performance, risks, decisions, glossary, and sign-off.

Capture decisions and unresolved questions in `design/decisions.md`; add agreed terms to `design/glossary.md`. The minimum signed-off set is `spec.md`, `decisions.md`, `bus-matrix.md`, `glossary.md`, and `entity-map.md` (with unavailable evidence marked). Phase 9 must include refresh cadence, expected volume/batch-sizing assumptions, performance constraints, and `architect_notes` for upstream-first design or partition decisions. Each phase ends with a user confirmation or an explicit deferred item with owner and impact. A contradiction reopens the affected phase. Repository write authorization and specification sign-off are separate gates.
