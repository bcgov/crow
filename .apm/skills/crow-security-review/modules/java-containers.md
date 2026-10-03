# Java container security review

Load only when Java runs behind an embedded/external Servlet server or Jakarta EE application server. Inspect effective deployment configuration, including edge proxy, framework properties, server config, image, and actual version. Separate confirmed exploitable paths from hardening suggestions; cite the server's version-specific docs and effective configuration.

## Cross-container checks

- Identify who patches the JDK, framework/server, libraries in the WAR/JAR, and base image. Check actual version support and Jakarta API compatibility; Tomcat, Jetty, and standalone Undertow are not full Jakarta EE application servers.
- Trace whether untrusted clients can supply trusted forwarding headers; check proxy allowlists, HTTPS and secure cookie behavior, connector exposure, request/upload/parameter limits, graceful shutdown, and access-log redaction.
- Check default/administration endpoints, management roles, local-only bindings, environment secrets, writable deploy/config directories, runtime user privileges, diagnostic error responses, and security headers. Confirm authorization and CSRF behavior in the application; a hardened server does not replace application controls.

## Server-specific evidence

| Server | Inspect |
|---|---|
| External Tomcat | `server.xml` connectors, `RemoteIpValve` trust settings, `context.xml` cookies, manager/host-manager/examples exposure, deployment privileges and writable paths. Disable unused AJP; if required, restrict reachability and configure `address`, `secret`/`secretRequired`, and allowed request attributes appropriately. Review shutdown-port exposure for the deployed mode. |
| Embedded Tomcat | Framework/server version, effective connector and proxy properties, management endpoints, session cookies, and image user; do not assume standalone files or manager apps exist. |
| Jetty | Enabled modules/environment, HTTP connectors and forwarding configuration, deployment/management access, request limits and TLS. |
| Undertow | Embedded/server-owned listeners, proxy forwarding trust, worker limits, management interface exposure (if hosted by an application server). |
| Jakarta EE application server (WildFly, Open Liberty, Payara, etc.) | Actual enabled Core/Web/Platform profile/features, management and application listener separation, security realms/roles, server-managed data sources, deployment credentials, TLS and update process. Do not assert vendor-specific defaults without version-specific evidence. |

## Sources

- Apache Tomcat, [Security Considerations](https://tomcat.apache.org/tomcat-11.0-doc/security-howto.html)
- Apache Tomcat, [AJP Connector](https://tomcat.apache.org/tomcat-11.0-doc/config/ajp.html)
- Apache Tomcat, [Remote IP Valve](https://tomcat.apache.org/tomcat-11.0-doc/config/valve.html#Remote_IP_Valve)
- Eclipse Jetty, [Jetty 12 Operations Guide](https://jetty.org/docs/jetty/12/operations-guide/index.html)
