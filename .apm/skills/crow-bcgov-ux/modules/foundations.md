# B.C. Design System Foundations

## Authority and currency

Verify current values and release status from:

- [Foundations](https://www2.gov.bc.ca/gov/content/digital/design-system/foundations)
- [Components](https://www2.gov.bc.ca/gov/content/digital/design-system/components)
- [Roadmap](https://www2.gov.bc.ca/gov/content/digital/design-system/roadmap)
- [Design tokens](https://www2.gov.bc.ca/gov/content/digital/design-system/foundations/design-tokens)
- [B.C. Design System repository](https://github.com/bcgov/design-system)

The design system is a work in progress. Use only released components and current package exports. Never substitute the archived legacy design system.

## Tokens and packages

- Prefer `@bcgov/design-tokens`, using the output compatible with the application's style pipeline. It is framework-neutral.
- React applications should prefer released exports from `@bcgov/design-system-react-components`.
- The React component package is React-only. Never add React to another application or port its implementation internals merely to consume it.
- Load BC Sans from the approved `@bcgov/bc-sans` distribution or the application's approved existing source. The React package does not bundle the font.
- Consume semantic tokens rather than copying resolved hex, pixel, shadow, or typography values into components.
- If official packages cannot be consumed, derive one centralized adapter from the current published token output. Document its source/version and replacement path. Do not maintain an unversioned snapshot in many files.

## Visual and structural foundations

### Typography

- BC Sans is required for new B.C. government digital services; use the documented fallback stack only while the approved font is unavailable.
- Use the current published type tokens. Do not treat a remembered scale as authoritative.
- Use one H1 per page and do not skip heading levels.
- Choose heading elements for document structure, not visual size.
- Keep body text readable at user-selected zoom and text spacing.

### Colour

- Use semantic design tokens for text, surfaces, borders, focus, links, and status.
- Meet at least 4.5:1 contrast for normal text and 3:1 for large text.
- Meet WCAG non-text contrast for controls, boundaries needed to identify controls, focus indicators, and meaningful graphics.
- Never use colour as the only indication of status, selection, validity, or required action.
- Preserve distinguishable link and interaction states.

### Layout

- Use the published spacing and sizing tokens.
- The B.C. Design System does not mandate a hard grid or publish a fixed breakpoint scale.
- Let content determine when layouts reflow. Use existing project breakpoints only when necessary.
- Support 320 CSS-pixel-equivalent reflow and 400% zoom without loss of content or functionality, except for legitimate two-dimensional content.
- Keep reading order and focus order consistent with visual order.

### Iconography

- Use the documented Font Awesome Free icons or suitable accessible SVGs. Do not assume a Font Awesome Pro licence.
- Icons supplement visible text; they do not replace it.
- Hide decorative icons from assistive technology.
- Give icon-only controls an accessible name, but prefer visible labels.
- Do not put essential text inside an SVG without an equivalent accessible text alternative.

## Component selection

1. Confirm the component is released in the current B.C. catalogue.
2. Use the official React component in React where it fits.
3. In other technologies, implement the documented semantics, appearance, states, and behaviour with native controls and official tokens.
4. If no component exists, use the simplest native pattern that meets the need and document it as project-specific.
5. Do not label a custom component as a B.C. Design System component.

## Published interaction rules to preserve

Verify these against the live component page before exact implementation:

- buttons include primary, secondary, tertiary, link, and destructive treatments; use one primary action per screen and retain the documented minimum target;
- fields expose default, hover, focus, invalid, disabled, and read-only states, with errors adjacent to the field;
- checkboxes and radios retain native group semantics, labels, invalid messaging, and correct disabled/indeterminate behaviour;
- dialogs manage focus, keyboard dismissal, background interaction, labelling, and return focus; distinguish an alert dialog requiring a decision from a general dialog;
- page-level alert banners and local inline alerts serve different scopes, and non-urgent alerts must not interrupt the user.

## Content and feedback

- Use plain, direct, task-oriented language and product-approved terminology.
- Make link and button text describe the destination or action out of context.
- Put instructions before the control they describe.
- Do not use placeholder text as a label.
- Make errors specific: identify the field/problem and explain how to correct it without blaming the user.
- Preserve entered values after validation failures where safe.
- Announce asynchronous status changes without unnecessarily moving focus.
- For automated eligibility, denial, or external-register results, explain the
  outcome at the point of use and provide the approved correction, review, or
  contact path. Identify pending, degraded, offline, stale, and assisted
  states instead of implying a final result.

## Sensitive information in forms

- Treat SINs and other sensitive identifiers as masked display values by default, including on edit-form page load.
- Reveal only the individual value the user needs after an explicit action and an authorization check appropriate to the application. Do not provide a page-level reveal-all action.
- Keep labels visible while masking the value. Mask the complete value by default; expose trailing or other identifying digits only when an approved product requirement and privacy/security assessment explicitly permit it. Do not imply that mask characters are the stored value.
- Provide an accessible show/mask toggle for the field and return it to the masked state when the editing context ends.
- Do not place the full value in the DOM, page source, accessible name, tooltip, URL, analytics, or client log merely to render a masked presentation. The implementation must preserve the application's established secure data-access boundary.
