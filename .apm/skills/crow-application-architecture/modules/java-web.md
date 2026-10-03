# Java web and container architecture

Load with `java.md` for Java HTTP workloads. Identify framework, HTTP stack, artifact type, container/version, Jakarta API level, and who owns its configuration before selecting guidance. An executable Spring Boot JAR and a WAR deployed to a separately operated server have different patch and configuration owners.

## Workload and API boundary

- Use Spring Boot/Spring MVC, Jakarta REST, or Servlet APIs according to existing contracts; do not introduce a second web stack for one endpoint. Keep HTTP request/response DTOs separate from persistence entities and version external APIs deliberately.
- Use standards-based OIDC/OAuth where appropriate and enforce authorization at the resource/action boundary. Set cookie/CSRF, CORS, secure transport, forwarded-header trust, and error response policies for the actual credential and proxy topology.
- Specify bounded request/body/upload sizes, connector/thread/connection limits, graceful shutdown, separate health probes, and observable dependency failure. Load [`java-containers.md`](../../crow-security-review/modules/java-containers.md) for container security acceptance.
- Tomcat, Jetty, and standalone Undertow provide Servlet/HTTP capabilities, not the complete Jakarta EE Web Profile or Platform; check which additional APIs the application supplies and which the server provides. Distinguish Java EE 8 / Tomcat 9 `javax.*` from Jakarta EE 9+ / Tomcat 10+ `jakarta.*` when upgrading a WAR and its filters.

## Container selection

| Deployment | Architecture check |
|---|---|
| Embedded Tomcat (Spring Boot default for Servlet apps) | Framework-managed Tomcat version, connector properties, JAR packaging, health probes, and patch ownership. |
| External Tomcat 10.1/11 | WAR lifecycle and server-wide vs per-app config ownership; verify Servlet/Jakarta namespace/spec and JDK compatibility. |
| Jetty 12 | Match the enabled Jetty environment and Servlet/Jakarta API version to the WAR; review standalone base/modules or embedded configuration separately. |
| Undertow | Identify whether embedded or provided by a larger server; verify listener, proxy, thread, and deployment config in its actual owner. |
| Jakarta EE application server (e.g. WildFly, Open Liberty, Payara) | Check product/version's enabled Core/Web/Platform profile and supplied APIs, server-managed security, transactions, and deployment descriptors before adding application libraries. Do not presume every server/version implements Jakarta EE 11. |

## Sources

- Apache Tomcat, [version/specification mapping](https://tomcat.apache.org/whichversion.html)
- Jakarta EE, [Platform 11](https://jakarta.ee/specifications/platform/11/)
- Spring Boot, [Servlet web applications](https://docs.spring.io/spring-boot/reference/web/servlet.html)
- Eclipse Jetty, [Jetty 12 Operations Guide](https://jetty.org/docs/jetty/12/operations-guide/index.html)
- Open Liberty, [documentation](https://openliberty.io/docs/latest/)
