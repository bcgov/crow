# Svelte and SvelteKit

- Use `@bcgov/design-tokens` through the existing global style or preprocessing pipeline. Do not port the official React components.
- Build from native semantic elements and the current published B.C. visual/state specification.
- Preserve Svelte's scoped-style conventions, and centralize design tokens and approved BC Sans setup in the global style pipeline.
- Avoid `{@html}` for ordinary or user-controlled content.
- Ensure actions and wrapper components preserve accessible names, descriptions, IDs, keyboard events, and disabled semantics.
- In SvelteKit client navigation, update metadata and deliberately manage focus/announcements.
- Test conditional blocks so removed elements do not strand focus and validation messages remain associated.
- Test portals/actions used for overlays against the dialog acceptance criteria.

Document project-specific components as adaptations, not official B.C. components.
