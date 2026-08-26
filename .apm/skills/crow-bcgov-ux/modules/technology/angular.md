# Angular and Angular Universal

- Use `@bcgov/design-tokens` through the workspace's established global or library style pipeline. Do not port the official React components.
- Load approved BC Sans assets once through the workspace's global style pipeline.
- Prefer native elements and Angular forms semantics. Preserve label, description, required, invalid, and error relationships in reusable controls.
- Support both the application's selected reactive/template-driven form approach and its existing error-display convention.
- Do not use click handlers on non-interactive elements to simulate controls.
- Avoid `DomSanitizer.bypassSecurityTrustHtml` and raw HTML rendering for design-system composition.
- With Angular routing, update the document title and deliberately manage focus/announcements after navigation.
- In Angular Universal, keep IDs and initial markup stable across server render and hydration.
- Test CDK overlays or custom overlays for accessible names, focus containment, Escape/dismiss behaviour, background interaction, and focus restoration.
- Preserve forced-colours and reduced-motion preferences when Angular animations are used.

Document project-specific components as adaptations, not official B.C. components.
