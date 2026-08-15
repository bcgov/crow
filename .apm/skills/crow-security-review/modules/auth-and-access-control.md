# Module: Authorization & Access Control

**Purpose:** Detect missing or bypassable authorization — SonarQube does not analyze authorization logic, access control consistency, or IDOR patterns.

## Detection Strategy

1. Use `search_graph` to enumerate all HTTP endpoints/routes
2. For each endpoint, use `trace_path direction="inbound"` to check if an authorization middleware/annotation/decorator is in the call chain
3. Flag endpoints handling sensitive data or state-changing operations without authorization

## Per-Framework Authorization Patterns

| Framework | Authorization Mechanism | Missing Auth Indicator |
|-----------|------------------------|------------------------|
| Spring Boot | `@PreAuthorize`, `@Secured`, `@RolesAllowed`, `SecurityFilterChain` | Controller method without any security annotation AND not in public allowlist |
| ASP.NET Core | `[Authorize]`, policy-based auth, `RequireAuthorization()` | Controller/action without `[Authorize]` AND not marked `[AllowAnonymous]` intentionally |
| Express/NestJS | Middleware (`passport`, guards), `@UseGuards()` | Route handler without auth middleware in its chain |
| Django | `@login_required`, `@permission_required`, DRF `permission_classes` | View without decorator AND not in `PUBLIC_URLS` |
| Laravel | `->middleware('auth')`, `Gate::`, `Policy` | Route without auth middleware in group |
| Go (stdlib/chi/gin) | Middleware function in chain | Handler registered without auth middleware wrapper |
| FastAPI | `Depends(get_current_user)`, security scopes | Endpoint without dependency injection of auth |
| Ruby on Rails | `before_action :authenticate_user!`, Pundit/CanCanCan | Controller action without `before_action` or policy check |

## IDOR Detection

For each endpoint accepting an entity ID parameter:
1. Trace from parameter extraction to database query
2. Check if a WHERE clause or filter constrains results to the authenticated user's scope
3. Flag if the query uses only the provided ID without ownership verification

### Language-Specific IDOR Patterns

| Framework | Vulnerable Pattern | Safe Pattern |
|-----------|-------------------|--------------|
| Spring Data | `repository.findById(id)` without user scope | `repository.findByIdAndUserId(id, currentUser.getId())` |
| EF Core | `context.Entities.Find(id)` without filter | `context.Entities.Where(e => e.Id == id && e.UserId == userId)` |
| Django ORM | `Model.objects.get(pk=id)` | `Model.objects.get(pk=id, owner=request.user)` |
| ActiveRecord | `Model.find(params[:id])` | `current_user.models.find(params[:id])` |
| Sequelize | `Model.findByPk(req.params.id)` | `Model.findOne({ where: { id, userId } })` |

## Privilege Escalation Checks

- Role/permission changes without re-authentication
- Admin endpoints accessible via direct URL without role check
- User-modifiable role fields in request bodies (mass assignment)
- Missing verification that the acting user has authority to grant/revoke roles

## What This Catches That SonarQube Doesn't

- Missing authorization on new endpoints (SonarQube doesn't understand route registration)
- IDOR patterns (requires understanding the auth context + query scope)
- Inconsistent authorization (some endpoints protected, similar ones not)
- Privilege escalation via direct object manipulation
- Horizontal privilege escalation (user A accessing user B's data)
- Mass assignment leading to role elevation
