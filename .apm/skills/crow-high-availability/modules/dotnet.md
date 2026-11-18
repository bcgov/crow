# .NET continuity deltas

Identify .NET versus .NET Framework, runtime version, ASP.NET hosting model,
IIS/application-pool ownership, self-contained versus framework-dependent
artifact, worker services and affected deployment units. Do not apply Generic
Host behavior to an unrelated legacy hosting model.

Reuse [ASP.NET Core architecture](../../crow-application-architecture/modules/aspnet-core.md)
and [application diagnostics](../../crow-application-development/modules/dotnet/diagnostics.md).
Assess only the continuity deltas:

- Host shutdown callbacks, cancellation and actual service/container deadlines;
  include `BackgroundService`/hosted work and forced termination, not only HTTP.
- Data Protection application identity, key persistence/distribution and
  key/cookie/antiforgery compatibility across versions. Separate session
  storage from cryptographic proof validation; shared session storage alone
  does not establish authentication continuity.
- IIS overlapped recycling, warm-up, proxy routing and shared-pool blast radius
  when observed; a recycle setting does not prove uninterrupted operations.
- Blazor/server-held UI state, SignalR or streaming reconnect/resume, old-client
  APIs and asset retention where present.
- Runtime update process boundaries: updating a pin or installed runtime is not
  evidence that running instances use it or can be replaced without interruption.

Ask the [update owner](../../../agents/crow-framework-dependency-update.agent.md)
to verify supported versions and deployment compatibility. Do not select or
apply versions here. Verify behavior against the actual installed version's
[Generic Host documentation](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/host/generic-host);
record source review dates in the consuming report.
