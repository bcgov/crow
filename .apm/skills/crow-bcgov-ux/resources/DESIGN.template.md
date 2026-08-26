---
version: 1
name: Application UX specification
description: B.C. Design System-aligned UX decisions for this application. Reference official semantic token names rather than copied resolved values.
sources:
  bcDesignSystem: https://www2.gov.bc.ca/gov/content/digital/design-system
  wcag: https://www.w3.org/TR/WCAG22/
tokens:
  typography: {}
  text: {}
  surface: {}
  border: {}
  focus: {}
  status: {}
  spacing: {}
  sizing: {}
  radius: {}
components: {}
---

# Application UX Specification

## Overview

Describe the visual and interaction characteristics of the application, its approved scope, and the B.C. Design System version/package evidence used. Do not include personas or user journeys.

## Principles

- Accessibility and semantic HTML are design inputs.
- Released B.C. components and semantic tokens are preferred.
- Project-specific adaptations are identified as adaptations.
- Responsive behaviour is based on reflow and content needs, not invented B.C. breakpoints.

## Typography

Document approved type roles and semantic token references. Include fallback behaviour without copying resolved package values.

## Colour

Group semantic token references by text, surface, border, focus, and status. Document contrast evidence and non-colour cues.

## Layout and responsive behaviour

Document spacing/container decisions, reflow behaviour, zoom expectations, and project breakpoints when required. State that project breakpoints are not official B.C. tokens.

## Components

For each shared component, record:

- official released component or project-specific adaptation;
- semantic token references;
- anatomy and content rules;
- reachable states;
- keyboard and focus behaviour;
- accessible name, description, error, and announcement behaviour;
- narrow-width and zoom behaviour.

## Forms and validation

Document labels, instructions, requirements, validation timing, field errors, summaries, focus, announcements, preservation of input, and confirmation. Identify sensitive fields, their default masked presentation, authorization boundary, accessible show/mask interaction, and when they return to the masked state.

## Motion

Document necessary motion and reduced-motion behaviour.

## Known gaps

List unpublished B.C. components, unavailable token/package evidence, project-specific adaptations, and manual verification still required. Never fill a gap with an invented official value.
