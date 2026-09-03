---
name: crow-bcgov-ux
description: Create, implement, review, or remediate accessible UX for B.C. government applications using the current B.C. Design System and WCAG 2.2 AA. Routes guidance for HTML/CSS, Razor, React/Next/Gatsby/Remix, Vue/Nuxt, Angular, Svelte, and Blazor. User-journey design is intentionally out of scope.
---

# B.C. Government UX

Use this skill to create or update an interface, review an existing application, or remediate UX and accessibility findings. It applies to B.C. government applications in any frontend technology currently covered by Crow.

This skill governs UX within supplied screens and flows. Personas, journey maps, service blueprints, discovery research, and redesign of end-to-end business journeys are intentionally deferred to a future workflow.

## Source hierarchy

Use sources in this order:

1. [B.C. Design System](https://www2.gov.bc.ca/gov/content/digital/design-system) foundations and released component documentation.
2. [B.C. Design System repository](https://github.com/bcgov/design-system) and published packages for exact tokens, component APIs, and release status.
3. [B.C. accessibility guidance](https://digital.gov.bc.ca/design/wcag/intro/) and [WCAG 2.2](https://www.w3.org/TR/WCAG22/) for conformance.
4. [WAI-ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/) for custom interaction behaviour not fully specified by B.C. documentation.
5. Established project conventions, when they do not conflict with the sources above.

The design system is evolving. Re-check live sources before relying on an exact token, package API, component state, or brand rule. Do not use the archived legacy B.C. design system. Do not infer an official component from a mock-up or an unreleased roadmap item.

## Context-efficient loading

Always load:

- [`modules/foundations.md`](modules/foundations.md);
- [`modules/accessibility.md`](modules/accessibility.md).

For an existing-app review or remediation, also load:

- [`modules/review-remediation.md`](modules/review-remediation.md).

When a supplied surface shows automated eligibility/denial, external register
results, or degraded/async/offline/assisted states, also load
[`modules/decision-and-service-states.md`](modules/decision-and-service-states.md).
When those states are caused by authentication, step-up, authorization,
expiry, revocation, or a dependency trust boundary, use the module's
technology-neutral guidance for clear status, safe continuation, and recourse.

Load only the matching technology module:

- HTML/CSS, server-rendered templates, CMS themes, or Razor: [`modules/technology/web.md`](modules/technology/web.md)
- React, Next.js, Gatsby, or Remix: [`modules/technology/react.md`](modules/technology/react.md)
- Vue or Nuxt: [`modules/technology/vue.md`](modules/technology/vue.md)
- Angular or Angular Universal: [`modules/technology/angular.md`](modules/technology/angular.md)
- Svelte or SvelteKit: [`modules/technology/svelte.md`](modules/technology/svelte.md)
- Blazor: [`modules/technology/blazor.md`](modules/technology/blazor.md)

For a mixed application, load only modules for affected rendered surfaces. Use [`resources/DESIGN.template.md`](resources/DESIGN.template.md) only when the user requests a durable UX specification or the repository already maintains a `DESIGN.md`.

## Establish the target

Before designing or editing:

1. Inspect manifests, UI entry points, shared layouts, styling pipeline, existing design-system dependencies, and accessibility tests.
2. Determine whether the work is a new UX, a focused update, a review only, or review plus remediation.
3. Identify the supplied screen/flow boundary and affected shared components.
4. Check current B.C. documentation for each relevant component. Record unpublished or undocumented needs as gaps rather than inventing official guidance.
5. Preserve business behaviour. Ask only when a missing decision materially changes interaction or product behaviour.

## Create or update workflow

1. **Structure:** define one page H1, logical heading levels, landmarks, reading order, and clear task-oriented content.
2. **Components:** prefer a released B.C. component; otherwise prefer a native HTML control composed with official tokens.
3. **States:** cover default, hover where relevant, focus, active/pressed, selected, disabled, read-only, loading, empty, success, warning, and error states that the component can reach.
4. **Forms:** provide persistent labels, instructions before input, programmatic requirements, field-level errors, an error summary for failed submissions where appropriate, and focus/announcement behaviour. Mask existing sensitive values such as SINs on initial display and reveal only the individual field needed through a deliberate, authorized, accessible control.
5. **Responsive behaviour:** design for content reflow and zoom, not arbitrary device labels. The B.C. Design System does not publish a fixed breakpoint scale; use the host application's established breakpoints only when the layout needs them.
6. **Accessibility:** apply every relevant acceptance criterion in the accessibility module before implementation.
7. **Implementation:** use official packages and the target framework's idioms. Centralize tokens and shared primitives; do not scatter copied values.
8. **Verification:** run the repository's existing linter/formatter, focused tests, build, accessibility automation, and required manual checks.
9. **Service states (when routed):** explain consequential automated or external decisions at the point of use, provide available recourse and provenance, and make degraded, pending, stale, offline, and assisted states clear without changing journey or policy design.

## Review and remediation workflow

1. Set and report scope: shared shell, component library, routes/screens sampled, states exercised, viewport/zoom coverage, and tooling available.
2. Review shared tokens and primitives first, then representative screens and exceptional states.
3. Record findings using the format in [`modules/review-remediation.md`](modules/review-remediation.md).
4. Prioritize blockers and shared root causes. Apply fixes only when remediation is requested.
5. Re-test each changed component in all affected states and usages.
6. Report:
   - findings fixed;
   - findings deferred and why;
   - regressions checked;
   - manual checks completed;
   - checks that still require users of assistive technology or device/browser coverage.

## Known design-system gaps

- No official fixed breakpoint token scale is published; verify reflow and use project breakpoints rather than inventing B.C. values.
- Cross-cutting patterns are primarily documented in individual component pages rather than a single patterns library.
- Content guidance is not a complete standalone foundation in the design-system site; use B.C. accessibility/plain-language guidance and product-approved content standards.
- The component catalogue is released incrementally. A missing component is not permission to present a custom component as official.
