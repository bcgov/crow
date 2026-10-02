---
name: crow-executive-report
description: Bundles the executive report workflow, templates, schema, dashboard assets, and renderer. Use with the Crow Executive Summary Report Agent.
---

# Executive Report Resources

Use the following bundled resources when creating an executive report:

- `executive-report-template.md` — Markdown report structure.
- `executive-report.html` — HTML dashboard template.
- `executive-report.min.css` — Dashboard stylesheet.
- `report-data.schema.json` — Schema for the model-generated report data.
- `render-report.ps1` — Deterministic HTML renderer.

Read source freshness and synthesis reconciliation instructions in the agent
before populating the report. `security_synthesis` in `report-data.json` is
optional; populate it only from a validated, current synthesis and the
bounded security control-assurance section. The renderer displays a short
conditional section and never computes or changes security severity or
component-priority scores.

The STRIDE heatmap is required. Populate `report-data.json.stride` from the
validated `security-review-synthesis.json.stride` array for schema version
`1.1`, preserving all six ratings and component names. For a legacy `1.0`
synthesis, or a legacy review without a synthesis artifact, use only a
complete Section 11 STRIDE table. The canonical seven-column legacy table is
accepted for migration; disclose that it lacks row-level evidence IDs and
rationale. Never derive ratings from prose.

Before rendering, run `Test-CrowExecutiveReportStride.ps1` with the report-data
path and scoped security-review path. Pass `-SynthesisPath` when the review
declares a synthesis artifact. This deterministic gate verifies the
report-data ratings against the source table, compares schema `1.1` values
across JSON and Markdown, and rejects unresolved or unsafe evidence references.
It also validates complete evidence records and confirms the report data,
review, and synthesis paths match the declared single-app or monorepo scope.
Do not render when validation fails. Run
`Test-CrowExecutiveReportStride.Tests.ps1` when changing this contract.

`render-report.ps1` displays an explicit “STRIDE ratings unavailable” row when
the field is missing or empty as a fail-safe for standalone use. That fallback
is not a valid executive report; the pre-render validation gate requires a
complete, source-matched matrix. Write generated reports to the target
repository's `docs/` directory; do not modify the bundled resources.

When a PDF is required on Windows, use Microsoft Edge's built-in headless
print-to-PDF support against the rendered HTML (for example, `msedge.exe
--headless --disable-gpu --no-pdf-header-footer
--print-to-pdf=<output.pdf> <input.html>`). Do not search for or install a
separate PDF tool in this case; use the standard Edge installation directly.
