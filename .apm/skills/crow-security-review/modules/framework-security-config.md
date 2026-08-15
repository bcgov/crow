# Module: Framework Security Configuration

**Purpose:** Detect security-relevant framework misconfigurations that require understanding the framework's security model — not individual code patterns. SonarQube sees individual files but does not understand application bootstrap, middleware registration order, or config-as-a-whole.

## Detection Strategy

1. Identify the detected frameworks from Step 4
2. Locate the primary configuration files for each framework
3. Check each configuration against the secure defaults table below
4. Flag deviations from secure defaults that are not justified by comments or architecture docs

## Per-Framework Security Defaults

### Spring Boot / Spring Security

| Config Location | Critical Setting | Insecure State |
|----------------|-----------------|----------------|
| `SecurityFilterChain` / `WebSecurityConfigurerAdapter` | CSRF protection | `.csrf().disable()` without API-only justification |
| `application.yml` / `application.properties` | Actuator exposure | `management.endpoints.web.exposure.include=*` |
| `application.yml` | Error details | `server.error.include-stacktrace=always` in non-dev profile |
| `application.yml` | Session fixation | `spring.session.store-type` without `changeSessionId` strategy |
| `SecurityFilterChain` | Frame options | `.headers().frameOptions().disable()` |
| `application.yml` | H2 Console | `spring.h2.console.enabled=true` in non-dev profile |

### ASP.NET Core

| Config Location | Critical Setting | Insecure State |
|----------------|-----------------|----------------|
| `Program.cs` / `Startup.cs` | Developer exception page | `app.UseDeveloperExceptionPage()` without `if (env.IsDevelopment())` guard |
| `Program.cs` / `Startup.cs` | HTTPS redirection | Missing `app.UseHttpsRedirection()` |
| `Program.cs` / `Startup.cs` | X-Frame-Options | `options.SuppressXFrameOptionsHeader = true` |
| `appsettings.json` | Detailed errors | `"DetailedErrors": true` in Production config |
| `Program.cs` | Antiforgery | Missing `builder.Services.AddAntiforgery()` for MVC apps |
| `Program.cs` | Auth middleware order | `UseAuthentication()` after `UseEndpoints()` |

### Django

| Config Location | Critical Setting | Insecure State |
|----------------|-----------------|----------------|
| `settings.py` | Debug mode | `DEBUG = True` in production settings |
| `settings.py` | Allowed hosts | `ALLOWED_HOSTS = ['*']` |
| `settings.py` | Secret key | `SECRET_KEY` hardcoded (not from env) |
| `settings.py` | CSRF trusted origins | Overly broad or `*` |
| `settings.py` | Session cookie | `SESSION_COOKIE_SECURE = False` |
| `settings.py` | CORS | `CORS_ALLOW_ALL_ORIGINS = True` |

### Express / Node.js

| Config Location | Critical Setting | Insecure State |
|----------------|-----------------|----------------|
| `app.js` / `server.js` | Helmet middleware | Not registered in middleware chain |
| `app.js` / `server.js` | Trust proxy | `app.set('trust proxy', true)` without reverse proxy |
| `app.js` / `server.js` | Error handler | Stack traces exposed in production error handler |
| `app.js` / `server.js` | Body parser limits | No `limit` option on body-parser (DoS risk) |
| CORS config | Origins | `origin: '*'` with `credentials: true` |
| Session config | Cookie secure | `secure: false` in production |

### Laravel

| Config Location | Critical Setting | Insecure State |
|----------------|-----------------|----------------|
| `.env` | App debug | `APP_DEBUG=true` in production |
| `.env` | App key | Default or empty `APP_KEY` |
| `config/cors.php` | Allowed origins | `'*'` with `supports_credentials: true` |
| `config/session.php` | Secure cookie | `'secure' => false` in production |
| `app/Http/Kernel.php` | CSRF middleware | `VerifyCsrfToken` removed from web middleware group |

### Next.js / Nuxt.js

| Config Location | Critical Setting | Insecure State |
|----------------|-----------------|----------------|
| `next.config.js` | Headers | Missing security headers in `headers()` config |
| `next.config.js` | Powered-by | `poweredByHeader: true` (default) |
| API routes | Auth | API route handlers without authentication check |
| `middleware.ts` | Route protection | Sensitive routes not covered by middleware matcher |

## Auto-Escaping Configuration

| Engine | Dangerous Disable Pattern | Detection |
|--------|--------------------------|-----------|
| Jinja2 | `Environment(autoescape=False)` | Search for `autoescape` in Python config |
| Django Templates | `{% autoescape off %}` blocks | Grep templates |
| Twig (PHP) | `'autoescape' => false` in config | Check `config/packages/twig.yaml` |
| Nunjucks | `new Environment(..., { autoescape: false })` | Search JS config |
| Handlebars | Triple-stash `{{{ }}}` widespread usage | Grep templates |
| Razor | `@Html.Raw()` widespread usage | Grep `.cshtml` files |

## What This Catches That SonarQube Doesn't

- Framework-level security disablement (SonarQube sees individual files, not config-as-a-whole)
- Production vs. development configuration drift
- Missing security middleware registration (requires understanding app bootstrap order)
- Misconfigured middleware ordering (auth after endpoints)
- Template engine global auto-escape disabled
