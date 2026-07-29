# Module: Frontend SPA Security

**Purpose:** Detect client-side security vulnerabilities in Single Page Applications (React, Vue, Angular, Svelte, Next.js, Nuxt). SonarQube detects basic XSS patterns like `dangerouslySetInnerHTML` but does not understand client-side auth logic, secret exposure through build-time env vars, SSR/client boundary leakage, or state management security.

## Detection Strategy

1. Identify frontend framework from `package.json` dependencies
2. Search for raw HTML rendering patterns per framework
3. Check for client-side authorization logic that can be bypassed
4. Audit build-time environment variables for secret exposure
5. Review SSR data serialization for server-to-client leakage
6. Assess state management for sensitive data persistence

## Framework Detection

| Indicator | Framework |
|-----------|-----------|
| `react`, `react-dom` in dependencies | React |
| `next` in dependencies | Next.js (React SSR) |
| `vue` in dependencies | Vue |
| `nuxt` in dependencies | Nuxt (Vue SSR) |
| `@angular/core` in dependencies | Angular |
| `svelte` in dependencies | Svelte |
| `@sveltejs/kit` in dependencies | SvelteKit (Svelte SSR) |
| `gatsby` in dependencies | Gatsby (React SSG) |
| `remix` in dependencies | Remix (React SSR) |

## XSS via Raw HTML Rendering

Each SPA framework auto-escapes by default but provides an opt-out for raw HTML. These are the primary client-side XSS vectors.

| Framework | Dangerous Pattern | Safe Alternative | Severity |
|-----------|------------------|-----------------|----------|
| React | `dangerouslySetInnerHTML={{ __html: userInput }}` | Render text content or use DOMPurify | HIGH |
| React | `ref.current.innerHTML = userInput` | Use state-driven rendering | HIGH |
| Vue | `v-html="userInput"` | `{{ userInput }}` (auto-escaped) | HIGH |
| Angular | `[innerHTML]="userInput"` with `bypassSecurityTrustHtml()` | Angular's built-in sanitizer (default) | HIGH |
| Angular | `DomSanitizer.bypassSecurityTrustHtml(input)` | Let Angular sanitize automatically | HIGH |
| Svelte | `{@html userInput}` | `{userInput}` (auto-escaped) | HIGH |

### URL Scheme Injection

React and other frameworks do NOT sanitize URL schemes. A user-controlled `href` can execute JavaScript.

| Framework | Dangerous Pattern | Severity |
|-----------|------------------|----------|
| React | `<a href={userInput}>` where input can be `javascript:alert(1)` | HIGH |
| React | `window.location = userInput` | HIGH |
| Vue | `:href="userInput"` without scheme validation | HIGH |
| Angular | `[href]="userInput"` (Angular sanitizes by default, but `bypassSecurityTrustUrl()` disables it) | HIGH |
| Any | `window.open(userInput)` | HIGH |

**Mitigation check:** URL must be validated against an allowlist of schemes (`https:`, `http:`, `mailto:`, `/relative`) before rendering.

## Client-Side Authorization (Bypass Risk)

Client-side auth checks are UX conveniences, not security controls. If the backend does not enforce the same checks, the app is vulnerable.

### Patterns to Flag

| Pattern | Risk | Severity |
|---------|------|----------|
| Route guards that only check a local token/flag without backend verification | Admin pages accessible by modifying localStorage | HIGH |
| Conditional rendering hiding UI based on `user.role` from client state | Attacker can modify state to reveal hidden functionality | MEDIUM |
| API calls that rely on client-side role checks instead of server-side enforcement | Unauthorized actions possible by calling API directly | HIGH |
| Feature flags stored in client-accessible config (no backend enforcement) | Premium features unlocked by modifying config | MEDIUM |

### Per-Framework Route Guard Patterns

| Framework | Guard Mechanism | What to Verify |
|-----------|----------------|----------------|
| React Router | `<PrivateRoute>` component, `loader` functions | Does the backend 403 if the user isn't authorized, or just the frontend redirect? |
| Next.js | `middleware.ts`, `getServerSideProps` redirect | Server-side middleware is safe; client-only checks in page components are not |
| Vue Router | `router.beforeEach()` navigation guards | Does the guard verify with the backend, or just check a local Vuex/Pinia flag? |
| Angular | `CanActivate` guards | Does the guard call an auth service that validates server-side, or just reads a local token? |
| SvelteKit | `+page.server.ts` load functions, hooks | Server load functions are safe; client-side `+page.ts` checks are bypassable |

**Key question:** If you delete `localStorage`/cookies and navigate directly to a "protected" URL, does the backend return 401/403, or does it serve the content?

## Secrets in Client Bundle

Environment variables prefixed with framework-specific public prefixes are embedded in the JavaScript bundle and visible to any user.

| Framework | Public Prefix | Exposed To Client |
|-----------|--------------|-------------------|
| React (CRA) | `REACT_APP_` | Yes — compiled into JS bundle |
| Next.js | `NEXT_PUBLIC_` | Yes — available in browser |
| Vue (Vite) | `VITE_` | Yes — compiled into JS bundle |
| Vue (CLI) | `VUE_APP_` | Yes — compiled into JS bundle |
| Angular | `environment.ts` files | Yes — bundled in build output |
| Svelte (Vite) | `VITE_` | Yes — compiled into JS bundle |
| Nuxt | `runtimeConfig.public` | Yes — serialized to client |
| Gatsby | `GATSBY_` | Yes — compiled into JS bundle |

### What MUST NOT Be in Public Env Vars

| Secret Type | Severity if Exposed |
|-------------|-------------------|
| API keys with write/admin access | CRITICAL |
| Database connection strings | CRITICAL |
| JWT signing secrets | CRITICAL |
| OAuth client secrets | HIGH |
| Internal service URLs | MEDIUM |
| Third-party API keys with usage limits | MEDIUM |

### What IS Acceptable in Public Env Vars

- Public API keys (e.g., Google Maps client key, Stripe publishable key)
- API base URLs for public endpoints
- Feature flags intended for client
- Analytics IDs (Google Analytics, Sentry DSN)

**Detection:** Search `.env*` files and `environment.ts` for the public prefixes, then assess each value.

## SSR Data Serialization (Server → Client Leakage)

SSR frameworks serialize server-fetched data into the HTML page for client hydration. If the server query returns more data than the client needs, sensitive fields leak to the browser.

| Framework | Data Serialization Point | Risk |
|-----------|--------------------------|------|
| Next.js | `getServerSideProps` / `getStaticProps` return value → `__NEXT_DATA__` script tag | All returned props are visible in page source |
| Next.js (App Router) | Server Components passing props to Client Components | Props are serialized to the client payload |
| Nuxt | `useAsyncData` / `useFetch` in `setup()` → `__NUXT_DATA__` | Server-fetched data hydrated to client |
| SvelteKit | `+page.server.ts` load function → serialized to page | Returned data visible in page source |
| Remix | `loader` function return → serialized to `__remixContext` | All loader data sent to client |
| Angular Universal | `TransferState` | State transferred to client bundle |

### What to Check

- Does `getServerSideProps` return the full database record (including `password_hash`, `email`, `internal_notes`) when only `name` and `avatar` are needed?
- Does the API response from `useFetch` include fields the UI doesn't render?
- Are admin-only fields (`is_admin`, `permissions`, `internal_id`) included in serialized data?

**Detection:** Read the return value of server data-fetching functions. Compare fields returned vs. fields actually rendered in the component.

## State Management Security

### Sensitive Data in Persistent State

| Pattern | Risk | Severity |
|---------|------|----------|
| Full user object (with tokens) stored in Redux/Vuex/Pinia persisted to localStorage | Token theft via XSS | HIGH |
| Payment information in client state | PCI compliance violation | CRITICAL |
| Session tokens in Redux DevTools-accessible state | Credential exposure in development | MEDIUM |
| Storing decrypted sensitive data in state longer than needed | Expanded attack window | MEDIUM |

### Per-Framework State Persistence

| Framework | Persistence Pattern | What to Check |
|-----------|--------------------|-|
| React | `redux-persist`, `zustand` with `persist` middleware | Which slices are persisted? Do they contain tokens/PII? |
| Vue | `vuex-persistedstate`, `pinia-plugin-persistedstate` | Which stores are persisted to localStorage? |
| Angular | `@ngrx/store` with custom localStorage sync | Which reducers write to storage? |
| Svelte | `$app/stores` with localStorage binding | Which stores survive page refresh? |

## Dependency-Specific Frontend Risks

| Package | Risk | What to Check |
|---------|------|---------------|
| `html-react-parser` | XSS if parsing user content | Is input sanitized before parsing? |
| `marked` / `markdown-it` | XSS via markdown rendering | Is `sanitize: true` or DOMPurify used? |
| `dompurify` | Safe — but check it's actually used before raw HTML rendering | Is it applied consistently? |
| `js-yaml` | Prototype pollution via `yaml.load()` | Use `yaml.load(data, { schema: SAFE_SCHEMA })` |
| `lodash` / `lodash.merge` | Prototype pollution via deep merge of user input | Validate input before deep merging |
| `serialize-javascript` | XSS if output is embedded in HTML without escaping | Check usage in SSR context |

## What This Catches That SonarQube Doesn't

- Client-side authorization bypass (SonarQube doesn't understand that frontend guards are not security controls)
- Secrets exposed through public env var prefixes (infrastructure/build concern, not code pattern)
- SSR data over-fetching leaking sensitive fields to the client (requires understanding component rendering vs. data returned)
- State management persisting tokens/PII to localStorage (requires understanding the full data flow)
- URL scheme injection in React/Vue `href` attributes (SonarQube may flag `dangerouslySetInnerHTML` but misses URL vectors)
- Client-side feature flag bypass enabling unauthorized functionality
