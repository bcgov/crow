# React, Next.js, Gatsby, and Remix

- Prefer released components from `@bcgov/design-system-react-components` and current official usage documentation.
- Read the installed package's `AGENTS.md` (0.9.0 or later). Treat `dist/index.d.ts` as the authoritative prop reference, including props inherited from `react-aria-components` types, and apply the [package version evidence](../foundations.md#package-version-evidence) rules.
- Import `@bcgov/design-tokens` and `@bcgov/bc-sans` through the application's existing style/build pipeline as required by current package documentation.
- Use component props and documented composition rather than bypassing them with ad hoc markup. Do not copy or fork the package's React Aria internals.
- Do not override a component's bundled styling with `className`. Use a styling hook only where the version-matched component documentation provides one; for example, `Form` accepts `className` to lay out a group of fields. Position components with surrounding flexbox or grid layout.
- For new forms, prefer the `Form` wrapper and the components' built-in state, validation, and error APIs; see [React Aria forms](https://react-aria.adobe.com/forms). Do not replace an established form library, submission or routing integration, server validation, or error summary without a request, and never nest forms.
- When no released component fits, compose React Aria Components primitives with official tokens, within the agreed dependency scope, and document the result as project-specific.
- Use the package's exported icon components where one fits. For other icons, use the Font Awesome Free release named in the installed `AGENTS.md`.
- Confirm package compatibility with the installed React version before changing dependencies.
- Preserve framework routing, server/client component boundaries, hydration behaviour, and established styling conventions.
- In Next.js, Remix, Gatsby, or another router, update document metadata and manage focus/announcements on client-side navigation.
- Use stable IDs (`useId` where appropriate) for labels, descriptions, and errors across server rendering and hydration.
- Do not use `dangerouslySetInnerHTML` for ordinary content or to reproduce design-system markup.
- Keep native form semantics even when state is controlled. Do not disable submit controls merely to hide validation; provide discoverable requirements and errors.
- Test released components in the application's actual composition, including portals, nested dialogs, suspense/loading states, and route transitions.

The B.C. React package uses React Aria primitives, but that does not eliminate the need to validate accessible names, composition, content, focus, and application-specific states.
