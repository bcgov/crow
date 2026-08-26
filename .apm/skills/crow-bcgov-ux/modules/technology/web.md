# HTML, CSS, Server Templates, CMS, and Razor

Use for plain HTML/CSS, server-rendered templates, CMS themes, and Razor views/pages.

- Import an appropriate published `@bcgov/design-tokens` CSS or SCSS output through the application's existing asset pipeline. Do not paste package output into individual components.
- Load approved BC Sans assets once and define the documented fallback stack.
- Build controls from native HTML first. Use `<button>` for actions and `<a href>` for navigation.
- Use server/framework helpers that preserve encoding, labels, validation relationships, antiforgery behaviour, and model-state errors.
- In Razor, prefer Tag Helpers and partials/view components already established by the application; do not bypass encoding to achieve styling.
- Keep CSS component-scoped or within the project's established cascade-layer/naming strategy. Avoid global element overrides, inline styles, `!important`, and raw design values outside the token adapter.
- Use CSS logical properties where compatible with project support requirements.
- Progressive enhancement is preferred: core content, navigation, forms, and validation remain understandable if optional client scripting fails.
- For CMS themes, keep editor-authored heading order and alternative-text requirements enforceable through templates and authoring guidance.

Verify generated HTML, not only template source. Check keyboard operation and accessibility tree after server-side validation.
