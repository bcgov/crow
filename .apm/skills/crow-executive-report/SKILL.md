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

Run `render-report.ps1` from this skill directory with the target repository's `report-data.json` path. Write generated reports to the target repository's `docs/` directory; do not modify the bundled resources.
