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

Run `render-report.ps1` from this skill directory with the target repository's `report-data.json` path. Write generated reports to the target repository's `docs/` directory; do not modify the bundled resources.

When a PDF is required on Windows, use Microsoft Edge's built-in headless
print-to-PDF support against the rendered HTML (for example, `msedge.exe
--headless --disable-gpu --no-pdf-header-footer
--print-to-pdf=<output.pdf> <input.html>`). Do not search for or install a
separate PDF tool in this case; use the standard Edge installation directly.
