# Java web container implementation

First identify server/version, embedded vs standalone, owning team, deployable artifact, proxy topology, and applicable Servlet/Jakarta specifications. Apply [`java-web.md`](../../../crow-application-architecture/modules/java-web.md) for selection and [`java-containers.md`](../../../crow-security-review/modules/java-containers.md) for review checks. Do not apply `server.xml` guidance to an embedded server without a `server.xml`.

| Server | Implementation focus |
|---|---|
| Embedded Tomcat | Configure via framework-supported properties/customizers; update the framework-managed server dependency with its release train. Verify connector bounds, forwarded-header handling, cookies, and shutdown under the actual framework version. |
| External Tomcat | Confirm WAR-to-Tomcat/Jakarta API compatibility; coordinate `server.xml`, `context.xml`, base directories, deploy manager, and patch cadence with the server owner. Keep writable application data outside deployment artifacts. For a Spring Boot WAR, use `SpringBootServletInitializer`, WAR packaging, and Maven `provided` / Gradle `providedRuntime` for the embedded server starter. |
| Jetty | Match enabled Jetty environment/modules to deployed WAR's Servlet API; verify server-level vs application-level connector and request limits. |
| Undertow | Identify embedded configuration or server owner (for example, WildFly); review listener, proxy, worker/thread and request limits at that layer. |
| WildFly, Open Liberty, Payara or another Jakarta EE application server | Check actual enabled Core/Web/Platform profile and server-managed APIs, security, transactions, and data sources. Use the server's tested deployment and configuration mechanism rather than assuming Tomcat controls apply. |

For all deployments, verify HTTPS and trusted proxy boundaries, bounded input/threads/connections, separate liveness/readiness, graceful draining, logs without sensitive headers, non-root identity, minimum privileges, and a patch/test/rollback owner. Test real configuration rather than assuming application-level defaults govern the external server.

## Sources

- Apache Tomcat, [version/specification mapping](https://tomcat.apache.org/whichversion.html)
- Apache Tomcat, [Security Considerations](https://tomcat.apache.org/tomcat-11.0-doc/security-howto.html)
- Eclipse Jetty, [Jetty 12 Operations Guide](https://jetty.org/docs/jetty/12/operations-guide/index.html)
- Jakarta EE, [Platform 11](https://jakarta.ee/specifications/platform/11/)
