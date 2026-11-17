# Hosts, application servers and plain containers

Use for observed VM/bare-host services, IIS/application servers, plain
containers and proxy/load-balancer pools. Containers alone do not imply an
orchestrator. Reuse the applicable language module; general hosting selection
already belongs to the
[hosting worksheet](../../../crow-solution-architecture/templates/hosting-choices-template.md).

Establish from configuration and supplied operational evidence:

- Individually addressable deployment units, independent routing/draining,
  instance placement, shared-host/pool blast radius, and remaining capacity.
- Who can remove/add a backend, how existing and new connections are handled,
  routing propagation, health/admission configuration and warm-up.
- Process supervisor/service-manager/application-server shutdown ordering and
  deadlines, forced termination, active requests and independently run jobs.
- Immutable artifact/configuration identity, replacement process, retained
  compatible artifacts and state outside replaceable release directories.
- Whether another application shares the runtime/server/process pool. Its
  maintenance dependency needs an owner; do not extend the assessed scope.

A single replace-in-place process without alternate service capacity or a
verified host-native continuity mechanism may require accepted interruption.
An overlapped restart or load balancer is a capability to verify, not proof.
Host/OS patching is excluded even when multiple hosts are present.
