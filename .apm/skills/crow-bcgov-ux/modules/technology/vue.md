# Vue and Nuxt

- Use `@bcgov/design-tokens` through the existing CSS/SCSS pipeline. The official B.C. React components are not Vue components and must not be ported directly.
- Load approved BC Sans assets once through the application's global style pipeline.
- Build Vue components with native elements and the semantics, states, appearance, and interaction documented for the released B.C. component.
- Preserve the project's Composition/Options API conventions and existing component/style architecture.
- In Nuxt and other client routers, update page metadata and manage focus or announcements after navigation.
- Forward attributes, IDs, labels, descriptions, invalid state, and event behaviour through wrapper components.
- Avoid `v-html` for ordinary or user-controlled content.
- Keep conditional rendering from unexpectedly discarding focus or validation messages; move focus deliberately when a step or view changes.
- Test teleported overlays for labelling, focus containment, background inertness, Escape behaviour, and focus restoration.

Document project-specific components as adaptations, not official B.C. components.
