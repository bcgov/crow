# Java continuity deltas

Confirm Java rather than another JVM language, JDK/JRE and framework versions,
embedded versus standalone server, JAR/WAR packaging, and deployment ownership.
Reuse [Java web architecture](../../crow-application-architecture/modules/java-web.md)
and [container guidance](../../crow-application-development/modules/java/containers.md).

Assess:

- Actual server/framework shutdown behavior, signal delivery and deadlines;
  do not infer deployed behavior from an IDE stop or another server's defaults.
- Warm-up, class loading/JIT, readiness and connection capacity before traffic.
- Session serialization/version compatibility, authentication keys and
  server-local state; replicated sessions are not automatically compatible
  across application versions.
- JMS/Kafka/other consumers, rebalancing, acknowledgements, active jobs,
  scheduler fencing and old/new event payload compatibility.
- External application-server shared resources, classloaders and co-deployed
  applications affected by a server/runtime update. Identify the owning team
  rather than claiming authority over shared infrastructure.

Hot reload/redeploy is not evidence of continuity. Consult the actual server
version and, only for Spring Boot, its
[graceful-shutdown documentation](https://docs.spring.io/spring-boot/reference/web/graceful-shutdown.html).
Defaults and persistent-connection behavior vary by release and server; record
dated evidence rather than copying a current default into a legacy assessment.
