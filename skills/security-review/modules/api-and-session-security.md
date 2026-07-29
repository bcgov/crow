# Module: API & Session Security

**Purpose:** Detect API security gaps, session management flaws, rate limiting absence, CORS misconfigurations, cookie flag issues, and JWT implementation weaknesses. SonarQube does not understand API authentication requirements, rate limiting architecture, or session configuration correctness.

## Detection Strategy

1. Enumerate all API endpoints via `search_graph` / `get_architecture`
2. For each endpoint, verify: authentication, authorization, rate limiting, input validation
3. Check session/cookie configuration for secure attributes
4. Assess JWT implementation for known attack vectors
5. Review CORS policy for credential leakage risk

## Rate Limiting Assessment

### What to Check

| Check | Risk if Missing | Where to Look |
|-------|----------------|---------------|
| Authentication endpoints (login, password reset) | CRITICAL — credential stuffing | Middleware config, API gateway |
| API endpoints with write operations | HIGH — abuse/DoS | Middleware config, reverse proxy |
| File upload endpoints | HIGH — storage DoS | Application or infra layer |
| Search/query endpoints | MEDIUM — resource exhaustion | Application code |
| Global rate limit | MEDIUM — DDoS baseline | Reverse proxy, API gateway |

### Per-Framework Rate Limiting

| Framework | Rate Limiting Mechanism | Where to Check |
|-----------|------------------------|----------------|
| ASP.NET Core | `Microsoft.AspNetCore.RateLimiting`, custom middleware | `Program.cs`, middleware pipeline |
| Spring Boot | `spring-boot-starter-cache` + interceptor, Bucket4j, Resilience4j | Interceptor config, filter chain |
| Express | `express-rate-limit` middleware | App middleware registration |
| Django | `django-ratelimit`, DRF throttling | Settings, view decorators |
| Laravel | `ThrottleRequests` middleware | `Kernel.php`, route middleware |
| FastAPI | `slowapi` | Middleware registration |

## CORS Misconfigurations

| Pattern | Risk | Severity |
|---------|------|----------|
| `Access-Control-Allow-Origin: *` + `Access-Control-Allow-Credentials: true` | Credential theft | CRITICAL |
| `Access-Control-Allow-Origin: *` on authenticated endpoints | Token leakage | HIGH |
| Reflecting `Origin` header without validation | Bypass restriction | HIGH |
| Wildcard on internal/admin APIs | Cross-origin access | MEDIUM |
| Missing CORS headers on public APIs (browser clients blocked) | Availability | LOW |

## Cookie & Session Configuration

| Attribute | Expected Value (Production) | Risk if Missing |
|-----------|---------------------------|----------------|
| `Secure` | `true` | Session hijacking over HTTP |
| `HttpOnly` | `true` | XSS-based session theft |
| `SameSite` | `Strict` or `Lax` | CSRF attacks |
| `Path` | Scoped to application path | Cookie leakage to other apps on same domain |
| Session timeout | < 30 minutes for sensitive apps | Persistent unauthorized access |
| Session regeneration on login | Must regenerate | Session fixation |
| Session invalidation on logout | Must destroy server-side | Session reuse |

### Per-Framework Session Config Location

| Framework | Config Location |
|-----------|----------------|
| ASP.NET Core | `builder.Services.AddSession()` options, cookie policy middleware |
| Spring Boot | `application.yml` → `server.servlet.session.*`, `SecurityFilterChain` |
| Express | `express-session` config object |
| Django | `settings.py` → `SESSION_*` variables |
| Laravel | `config/session.php` |
| Rails | `config/initializers/session_store.rb` |

## JWT Security Assessment

| Vulnerability | Detection Pattern | Severity |
|--------------|-------------------|----------|
| `alg: none` accepted | Token validation without algorithm enforcement | CRITICAL |
| Symmetric key too short | HMAC secret < 256 bits | HIGH |
| No expiry (`exp` claim) | Token never expires | HIGH |
| Long-lived tokens (> 1 hour) without refresh | `exp` set far in future | MEDIUM |
| Secret in source code | JWT secret hardcoded | CRITICAL |
| RS256/RS512 key confusion | Accepts HMAC with RSA public key as secret | CRITICAL |
| No audience (`aud`) validation | Token accepted across services | MEDIUM |
| No issuer (`iss`) validation | Tokens from other issuers accepted | MEDIUM |
| Token in URL query parameter | Leaks in logs, referrer headers | HIGH |
| No token revocation mechanism | Cannot invalidate compromised tokens | MEDIUM |

### Per-Framework JWT Patterns

| Framework | Library | Config to Check |
|-----------|---------|----------------|
| ASP.NET Core | `Microsoft.AspNetCore.Authentication.JwtBearer` | `TokenValidationParameters` — verify `ValidateIssuer`, `ValidateAudience`, `ValidateLifetime` all `true` |
| Spring Boot | `spring-security-oauth2-jose` | `JwtDecoder` config — verify algorithm, issuer, audience |
| Express | `jsonwebtoken`, `express-jwt` | `jwt.verify()` options — check `algorithms` array explicitly set |
| Django | `djangorestframework-simplejwt` | `SIMPLE_JWT` settings — verify `ALGORITHM`, `SIGNING_KEY`, `ACCESS_TOKEN_LIFETIME` |
| FastAPI | `python-jose`, `PyJWT` | `jwt.decode()` — verify `algorithms` parameter explicitly set |

## API Input Validation

| Issue | What to Check |
|-------|--------------|
| Missing content-type validation | API accepts unexpected content types |
| No request size limits | Large payloads can cause OOM/DoS |
| Array/object depth not limited | Deeply nested JSON can cause stack overflow |
| Batch endpoints without item limits | Unbounded batch operations |
| GraphQL without query complexity limits | Deeply nested/recursive queries |
| File upload without type/size validation | Arbitrary file upload |

### Anti-Forgery & HTTP Verb Enforcement

State-changing endpoints MUST have anti-forgery protection AND explicit HTTP verb constraints. Catch-all endpoints (no verb attribute) accept any method including GET, enabling CSRF and cache poisoning.

#### ASP.NET Core / ASP.NET MVC

**Anti-forgery check:**
- Every controller action with `[HttpPost]`, `[HttpPut]`, `[HttpDelete]`, or `[HttpPatch]` in MVC controllers (non-API) MUST have `[ValidateAntiForgeryToken]` or the controller-level `[AutoValidateAntiforgeryToken]` attribute
- API controllers (`[ApiController]`) using cookie/session auth MUST also validate — use `[AutoValidateAntiforgeryToken]` at controller level or custom filter
- `[IgnoreAntiforgeryToken]` on state-changing actions is a finding unless justified (e.g., webhook endpoint with HMAC validation)
- Check that `builder.Services.AddAntiforgery()` is configured and `@Html.AntiForgeryToken()` / `asp-antiforgery="true"` is used in forms

**HTTP verb enforcement:**
- Every controller action MUST have an explicit HTTP verb attribute (`[HttpGet]`, `[HttpPost]`, `[HttpPut]`, `[HttpDelete]`, `[HttpPatch]`)
- Actions without a verb attribute accept ALL HTTP methods — flag as MEDIUM severity
- `[AcceptVerbs("GET", "POST")]` combining read and write verbs on a single action is suspicious
- `[Route]` without a verb attribute is a catch-all — flag unless paired with a verb attribute

| Pattern | Severity | Rationale |
|---------|----------|-----------|
| `[HttpPost]` without `[ValidateAntiForgeryToken]` (MVC) | HIGH | CSRF exploitation on state-changing action |
| Controller action without any `[Http*]` attribute | MEDIUM | Catch-all accepts unexpected methods |
| `[IgnoreAntiforgeryToken]` on state-changing action | MEDIUM | Intentional bypass needs justification |
| `[AcceptVerbs("GET", "POST")]` on single action | LOW | Mixed semantics, review needed |

#### Spring Boot / Spring MVC

**CSRF check:**
- CSRF protection enabled by default in Spring Security — check it is NOT disabled: `.csrf().disable()` or `csrf(csrf -> csrf.disable())`
- If CSRF is disabled, verify the application is API-only with token-based auth (no cookies)
- State-changing endpoints (`@PostMapping`, `@PutMapping`, `@DeleteMapping`, `@PatchMapping`) rely on Spring Security's CSRF filter — ensure it's in the filter chain

**HTTP verb enforcement:**
- Every `@RequestMapping` MUST specify `method = RequestMethod.X` or use specific annotations (`@GetMapping`, `@PostMapping`, etc.)
- `@RequestMapping("/path")` without `method` attribute accepts ALL HTTP methods — flag as MEDIUM
- `@RequestMapping(value = "/path", method = {RequestMethod.GET, RequestMethod.POST})` combining verbs is suspicious

| Pattern | Severity | Rationale |
|---------|----------|-----------|
| `@RequestMapping` without `method` | MEDIUM | Catch-all endpoint accepts any HTTP method |
| `.csrf().disable()` with cookie-based auth | HIGH | CSRF protection removed for session-based app |
| `.csrf(csrf -> csrf.disable())` without justification | HIGH | Same as above (newer Spring Security API) |

#### Django / Django REST Framework

**CSRF check:**
- Django has CSRF middleware enabled by default (`django.middleware.csrf.CsrfViewMiddleware`)
- `@csrf_exempt` on state-changing views is a finding unless justified (e.g., API with token auth)
- DRF `SessionAuthentication` requires CSRF — verify `DEFAULT_AUTHENTICATION_CLASSES` does not mix session + exempt views
- Check `CSRF_TRUSTED_ORIGINS` is not overly broad

**HTTP verb enforcement:**
- Function-based views using `@api_view` MUST specify allowed methods: `@api_view(['POST'])` 
- `@api_view()` without methods argument or `@api_view(['GET', 'POST', 'PUT', 'DELETE'])` accepting all verbs is suspicious
- Class-based views should only implement the HTTP method handlers they need (`def post(self, request)`) — unused methods return 405 by default
- Check for `if request.method == 'POST'` branches inside GET-allowed views (state-change via GET)

| Pattern | Severity | Rationale |
|---------|----------|-----------|
| `@csrf_exempt` on state-changing view | HIGH | CSRF protection bypassed |
| `@api_view()` without explicit methods list | MEDIUM | Accepts all HTTP methods |
| State-changing logic inside a GET-allowed view | HIGH | CSRF via GET request |

#### Express / NestJS (Node.js)

**CSRF check:**
- `csurf` or `csrf-csrf` middleware should be applied to state-changing routes when using cookie/session auth
- Missing CSRF middleware on routes that use `express-session` is a finding
- API-only apps with bearer token auth can skip CSRF — verify auth mechanism

**HTTP verb enforcement:**
- Routes should use specific verb methods: `app.post()`, `app.put()`, `app.delete()`, `router.patch()`
- `app.all('/path', handler)` or `app.use('/path', handler)` on specific paths accepts all methods — flag as MEDIUM
- `router.all()` catch-all routes should be reviewed for unintended method acceptance
- NestJS: Controllers should use `@Post()`, `@Put()`, `@Delete()`, `@Patch()` — a handler without a method decorator is unreachable (safe by default)

| Pattern | Severity | Rationale |
|---------|----------|-----------|
| `app.all('/api/...')` on state-changing endpoint | MEDIUM | Accepts GET (cacheable, CSRF-able) |
| Missing CSRF middleware with session-based auth | HIGH | CSRF exploitation possible |
| `app.use('/path', handler)` as route handler | MEDIUM | Catch-all method acceptance |

#### Laravel

**CSRF check:**
- `VerifyCsrfToken` middleware is applied to all web routes by default
- Routes in `routes/api.php` skip CSRF (token-based auth expected) — verify they actually use token auth
- `$except` array in `VerifyCsrfToken` middleware — each exemption is a potential finding
- `@csrf` directive must be present in all `<form>` tags in Blade templates

**HTTP verb enforcement:**
- Routes should use specific verbs: `Route::post()`, `Route::put()`, `Route::delete()`
- `Route::any('/path', ...)` accepts all HTTP methods — flag as MEDIUM
- `Route::match(['get', 'post'], '/path', ...)` combining read and write verbs is suspicious
- Resource routes (`Route::resource()`) are safe — they map verbs correctly

| Pattern | Severity | Rationale |
|---------|----------|-----------|
| `Route::any()` on non-utility endpoint | MEDIUM | Catch-all accepts unexpected methods |
| Route in `$except` array of `VerifyCsrfToken` | MEDIUM | CSRF exemption needs justification |
| Missing `@csrf` in Blade `<form>` | HIGH | Form submits without CSRF token |

#### Ruby on Rails

**CSRF check:**
- `protect_from_forgery` is included by default in `ApplicationController`
- `skip_forgery_protection` or `skip_before_action :verify_authenticity_token` on state-changing actions is a finding
- API controllers inheriting from `ActionController::API` skip CSRF by default — verify they use token auth

**HTTP verb enforcement:**
- Routes should use specific verbs: `post '/path'`, `put '/path'`, `delete '/path'`
- `match '/path', via: :all` or `match '/path'` without `via:` is a catch-all — flag as MEDIUM
- `resources` and `resource` routes are safe — they enforce proper verb mapping

| Pattern | Severity | Rationale |
|---------|----------|-----------|
| `match` route without `via:` constraint | MEDIUM | Catch-all method acceptance |
| `skip_forgery_protection` on state-changing action | HIGH | CSRF protection removed |
| API controller using cookies without CSRF | HIGH | Session-based API without protection |

## What This Catches That SonarQube Doesn't

- Missing rate limiting on authentication endpoints (architectural concern)
- CORS misconfiguration combinations (wildcard + credentials)
- JWT implementation weaknesses (algorithm confusion, missing validation parameters)
- Session configuration drift between environments
- API endpoints missing authentication entirely (requires understanding route registration)
- Missing input validation at the API boundary level
- Missing anti-forgery tokens on state-changing controller actions (requires understanding the auth model)
- Catch-all endpoints without explicit HTTP verb constraints (requires understanding route semantics)
- CSRF exemptions that are unjustified given the authentication mechanism
