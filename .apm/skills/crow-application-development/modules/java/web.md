# Java web development

- Identify Servlet/Spring MVC vs reactive web stack, actual server, JAR/WAR packaging, and security filter chain before editing. Use the parent `api-contracts.md` for REST/SOAP changes.
- Keep authentication and authorization in framework-managed filters/interceptors and enforce per-resource access in the owning service. Do not assume `authenticated()` grants tenant/object access.
- For Spring Security, define explicit `SecurityFilterChain` rules and test fallback/default-deny behavior for private endpoints. Cookie/session authenticated writes need CSRF protection; token-only APIs may exclude the appropriate routes only after proving browsers do not authenticate them with cookies.
- Restrict CORS to approved origins/methods/headers; configure secure, HttpOnly, appropriate SameSite session cookies and session fixation protections. Avoid revealing internal exception details; use an intentional API error contract such as RFC 9457 Problem Details where supported.
- Bound body/multipart uploads, parameter counts, pagination, and expensive queries at the entry point and container. Configure trusted proxy headers on the actual server/edge only; do not accept client-supplied forwarding headers unconditionally.
- Limit management/Actuator endpoints and diagnostic content to authorized operators; distinguish liveness and readiness and test graceful shutdown/restart behavior.
- For WARs, check container-provided APIs and deployment descriptors; do not package duplicate Servlet APIs. When deploying Spring Boot to an external server, use a WAR with `SpringBootServletInitializer` and set the embedded server starter to Maven `provided` or Gradle `providedRuntime`. For container changes also load [`containers.md`](containers.md) and [`java-containers.md`](../../../crow-security-review/modules/java-containers.md).

## Sources

- Spring Security, [Authorize HTTP Requests](https://docs.spring.io/spring-security/reference/servlet/authorization/authorize-http-requests.html)
- Spring Security, [CSRF protection](https://docs.spring.io/spring-security/reference/servlet/exploits/csrf.html)
- Spring Boot, [Actuator endpoints](https://docs.spring.io/spring-boot/reference/actuator/endpoints.html)
- Spring Boot, [Traditional deployment](https://docs.spring.io/spring-boot/how-to/deployment/traditional-deployment.html)
- RFC Editor, [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457)
