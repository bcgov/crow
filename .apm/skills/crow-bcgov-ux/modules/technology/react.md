# React, Next.js, Gatsby, and Remix

- Prefer released components from `@bcgov/design-system-react-components` and current official usage documentation.
- Import `@bcgov/design-tokens` and `@bcgov/bc-sans` through the application's existing style/build pipeline as required by current package documentation.
- Do not copy or fork the package's React Aria internals. Use the documented component API.
- Confirm package compatibility with the installed React version before changing dependencies.
- Preserve framework routing, server/client component boundaries, hydration behaviour, and established styling conventions.
- In Next.js, Remix, Gatsby, or another router, update document metadata and manage focus/announcements on client-side navigation.
- Use stable IDs (`useId` where appropriate) for labels, descriptions, and errors across server rendering and hydration.
- Do not use `dangerouslySetInnerHTML` for ordinary content or to reproduce design-system markup.
- Keep native form semantics even when state is controlled. Do not disable submit controls merely to hide validation; provide discoverable requirements and errors.
- Test released components in the application's actual composition, including portals, nested dialogs, suspense/loading states, and route transitions.

The B.C. React package uses React Aria primitives, but that does not eliminate the need to validate accessible names, composition, content, focus, and application-specific states.
