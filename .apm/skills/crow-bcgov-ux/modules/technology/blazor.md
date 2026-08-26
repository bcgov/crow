# Blazor

- Use `@bcgov/design-tokens` CSS through the application's established static asset pipeline. Do not add React or port the official React component implementation.
- Load approved BC Sans assets once through the application's global static assets.
- Build reusable Razor components around native elements and current B.C. component specifications.
- Use `InputBase<T>`-compatible controls where appropriate so labels, validation state, messages, and `EditContext` behaviour remain coherent.
- Preserve generated IDs and connect labels, help text, validation messages, and summaries programmatically.
- Forward unmatched attributes safely so consumers can provide accessible names and descriptions without replacing semantics.
- Avoid unnecessary JavaScript interop. When focus management or platform behaviour requires it, keep interop narrow and test failure/disposal paths.
- Do not use `MarkupString` or raw HTML to reproduce design-system component markup.
- On enhanced/client-side navigation, update the page title and manage focus/announcements deliberately.
- Test prerendering and interactive hydration for duplicate IDs, transient unlabeled controls, and focus loss.
- Test dialogs and dynamic updates with the same keyboard, focus, inert-background, and announcement criteria as other technologies.

Document project-specific components as adaptations, not official B.C. components.
