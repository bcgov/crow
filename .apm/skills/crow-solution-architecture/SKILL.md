---
name: crow-solution-architecture
description: Design a B.C.-aligned solution architecture through evidence-first discovery and a focused stakeholder interview, producing canonical Markdown and an accessible rich HTML review with explicit defaults, fallbacks, identity, payment, and common-component decisions.
---

# Solution Architecture

Use this skill to design a new solution or materially reshape an existing one.
Use `crow-architecture-review` instead when the goal is to document the
architecture that source code currently implements.

## Context-efficient loading

1. Load [`modules/engagement-workflow.md`](modules/engagement-workflow.md) and
   [`modules/defaults-and-fallbacks.md`](modules/defaults-and-fallbacks.md) for
   every engagement.
2. Load
   [`../crow-application-architecture/modules/principles.md`](../crow-application-architecture/modules/principles.md),
   [`../crow-application-architecture/modules/minimal-change.md`](../crow-application-architecture/modules/minimal-change.md),
   and
   [`../crow-application-architecture/modules/unicode-and-utf8.md`](../crow-application-architecture/modules/unicode-and-utf8.md)
   for every proposed application.
3. Load
   [`../crow-application-architecture/modules/platform-alignment.md`](../crow-application-architecture/modules/platform-alignment.md)
   when a common component, shared platform, canonical register, public
   service, or one-to-many integration may apply.
4. Load [`modules/bc-identity.md`](modules/bc-identity.md) when people,
   organizations, administrators, APIs, or workloads cross a trust boundary.
   Also load
   [`../crow-application-architecture/modules/zero-trust.md`](../crow-application-architecture/modules/zero-trust.md).
5. Load [`modules/bc-platform-services.md`](modules/bc-platform-services.md)
   when the solution accepts payments or could reuse a B.C. government common
   component.
6. Load technology modules from `crow-application-architecture` only for
   technologies selected or already constrained by the solution. Add future
   stacks as sibling modules there; do not embed framework detail here.
   Add business-area guidance as a conditionally loaded
   `modules/domain-<name>.md` module with observable routing triggers, an
   accountable source owner, evidence freshness requirements, and explicit
   non-goals. Never load all domain modules by default.
7. Use
   [`templates/solution-architecture-template.md`](templates/solution-architecture-template.md)
   as the canonical source and
   [`templates/solution-architecture-template.html`](templates/solution-architecture-template.html)
   as the human-review surface. Use
   [`scripts/Test-SolutionArchitectureOutput.ps1`](scripts/Test-SolutionArchitectureOutput.ps1)
   before and after writing.

## Workflow

1. Inspect the repository, existing architecture records, `crow.config`,
   manifests, deployment definitions, relevant authoritative references, and
   the initial repository change list.
2. Present discovered facts and concrete assumptions. Follow the interview
   sequence in `engagement-workflow.md`, asking one focused question at a time
   only for unresolved decisions that materially change the architecture.
3. Classify constraints and quality attributes before selecting products.
4. Apply the default architecture and preferred stack. Use a fallback only
   when a recorded constraint defeats the default.
5. Evaluate common capabilities before custom builds. Verify current service
   ownership, eligibility, support, integration, data, and availability terms.
6. Design identity and authorization from user populations, assurance,
   protected resources, and operations rather than from provider names alone.
7. Run the validator in `PreWrite`, write or update canonical
   `docs/solution-architecture.md`, and then run
   `scripts/Render-SolutionArchitecture.ps1 -RepoRoot <repository-root>` to create
   `docs/solution-architecture.html`. The deterministic renderer HTML-encodes
   source content and records the Markdown SHA-256.
8. Use native HTML features, responsive cards and tables, `<details>` sections,
   and accessible inline SVG where they clarify UX examples, workflows, data
   flows, implementation choices, risks, or decision status. Do not depend on
   remote scripts, fonts, styles, or images.
9. Pass `-JsonOutputPath docs/solution-architecture-data.json` to the renderer
   only when structured data is needed for a chart, filter, or implementation
   hand-off. Treat it as derived data and do not make the HTML depend on
   fetching it at runtime.
10. Run the validator in `PostWrite`, then summarize the chosen architecture,
   departures from defaults, open
   decisions, evidence limitations, and validation result.
11. Compare the final repository change list with the initial list. Stop rather
    than report success if the workflow newly changed a path other than
    `docs/solution-architecture.md`, `docs/solution-architecture.html`, or the
    optional `docs/solution-architecture-data.json`.

## Failure behavior

- Record unavailable optional evidence as `Unknown` and identify who must
  resolve it.
- Do not silently choose among materially different identity, hosting, data,
  payment, or availability options.
- Do not turn a dependency outage or unknown authorization decision into a
  successful business outcome.
- Do not write a final design while any decision marked `Blocked` changes a
  trust boundary, legal obligation, recovery objective, or committed external
  contract.

## Completion gate

- The interview log shows the disposition of every material assumption.
- The recommended option, fallback trigger, consequences, owner, and
  confidence are explicit for major decisions.
- Public sources include a review date; private evidence is summarized without
  identifiers or copied source.
- The generated Markdown and HTML contain no template placeholders, the HTML
  records the current Markdown source hash, and both pass the bundled
  validator.
- Optional JSON is valid, derived from the Markdown, and carries the same
  source hash.
