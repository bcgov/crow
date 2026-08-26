# Accessibility Acceptance Criteria

B.C. government digital services must meet [WCAG 2.2 Level AA](https://www.w3.org/TR/WCAG22/). Use [B.C. WCAG guidance](https://digital.gov.bc.ca/design/wcag/intro/) for government context and [WAI-ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/) when a custom widget is unavoidable.

Automated tools find only a subset of accessibility defects. Do not claim conformance from a clean automated scan.

## Semantic and perceivable

- Use native landmarks, headings, lists, tables, links, buttons, and form controls for their intended purpose.
- Provide text alternatives for meaningful non-text content and hide decorative content.
- Associate every form control with a persistent programmatic label.
- Associate help and error text through native relationships or `aria-describedby`; expose invalid state programmatically.
- Provide captions/transcripts and audio description where applicable.
- Support browser text spacing overrides without clipping or loss.
- Do not convey information through colour, position, shape, sound, or icon alone.
- Keep text and non-text contrast compliant in every state.

## Keyboard and focus

- Every interactive function works with a keyboard without timing traps.
- Use logical DOM order; do not use positive `tabindex`.
- Keep focus visible, sufficiently contrasted, and not fully obscured by sticky content.
- Do not remove focus styles without an equally visible replacement.
- On opening a dialog, move focus according to the APG pattern, contain it while modal, support Escape where dismissal is allowed, and return it to a logical trigger.
- On route/view changes in SPAs, set an appropriate document title and deliberately manage focus or announce the new view.
- Skip repeated blocks with a working skip link or equivalent landmark navigation.

## Pointer, touch, and motion

- Meet WCAG 2.2 AA target-size minimums and spacing exceptions; where the B.C. component specifies a larger target, use the B.C. requirement.
- Provide a single-pointer alternative for dragging interactions.
- Do not require path-based or multipoint gestures.
- Ensure pointer cancellation and avoid firing destructive actions on pointer-down.
- Respect `prefers-reduced-motion`; remove non-essential motion and never rely on motion alone to explain state.
- Avoid flashes that violate seizure thresholds.

## Reflow and responsive behaviour

- Verify at 400% browser zoom and at a 320 CSS-pixel-equivalent viewport.
- Avoid horizontal scrolling for ordinary content; document legitimate exceptions such as complex data tables or maps.
- Do not lock orientation unless essential.
- Ensure sticky headers, cookie notices, and floating controls do not obscure focused content.
- Preserve usable control labels, errors, and actions at narrow widths and with 200% text sizing.

## Forms, errors, and authentication

- Identify required fields in text and programmatically before submission.
- Validate at an appropriate time; avoid disruptive validation on every keystroke.
- Link an error summary to invalid controls where a submitted form has multiple fields, focus the summary when appropriate, and retain user input.
- Announce errors and asynchronous success/status messages with the least intrusive suitable live-region behaviour.
- Provide review, correction, and confirmation for legal, financial, or destructive submissions.
- Mask sensitive values such as Social Insurance Numbers when a view or edit form first renders. Reveal only the specific field needed after a deliberate authorized user action; never reveal every sensitive value as a side effect.
- Give show/mask controls an accessible name that identifies the field, expose their state with visible text and `aria-pressed` where appropriate, support keyboard operation, and do not move focus when toggling visibility. Programmatically communicate that the value was shown or masked, but do not announce the sensitive value itself through a live region; it must be available from the field when the user navigates to it.
- Keep a user-controlled way to mask the value again, and re-mask it when the editing context ends or the application otherwise clears sensitive screen content. Masking is presentation protection, not a substitute for authorization, secure transport, storage, logging, or clipboard controls.
- Do not require users to solve cognitive-function tests for authentication when an accessible alternative or assistance mechanism is required by WCAG 2.2.
- Support password managers, paste, and accessible multi-factor methods.

## Time, status, and dynamic updates

- Let users extend or disable time limits unless an allowed exception applies.
- Warn before session expiry and preserve work where the product permits.
- Use `aria-live` or `role="status"`/`role="alert"` only for appropriate dynamic messages; do not create duplicate or overly verbose announcements.
- Loading states expose a programmatic name/status and do not trap focus.

## Verification

Run existing project tooling first. Supplement it with manual checks:

1. keyboard-only operation, including reverse tab order and Escape;
2. focus visibility, order, restoration, and no obscured focus;
3. browser zoom/reflow and text spacing;
4. high-contrast/forced-colours behaviour where the platform supports it;
5. reduced-motion preference;
6. screen-reader smoke tests for changed complex widgets and forms;
7. accessible names, roles, values, descriptions, errors, and live announcements;
8. contrast checks for every interaction and validation state.

Record browser, viewport/zoom, assistive technology, and tooling versions for formal reviews. State any checks not performed.
