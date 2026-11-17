# Orchestrated containers

Identify the actual platform/version, workload controller, routing data plane,
capacity/quotas, placement and operator ownership. Apply Kubernetes/OpenShift
terms only when observed; map equivalent controls on another orchestrator.

Assess desired versus supplied actual replicas, placement/failure domains,
requests/limits, replacement concurrency and surge/unavailable settings,
startup/warm-up and scheduling capacity while a unit is unavailable.
Autoscaling cannot replace measured headroom or guaranteed surge capacity.

Trace readiness/admission, endpoint withdrawal and proxy propagation,
pre-stop behavior, application signal handling, worker drain and force-kill
deadline as one timeline. Endpoint removal and application shutdown can race.
Derive any wait/margin from measured behavior; a fixed sleep is not a
continuity guarantee. Termination hooks may share the same total grace budget.

Distinguish rollout controls from voluntary-disruption controls; a disruption
budget alone does not establish safe application rollout. Include failed
readiness, image start failure, force termination and insufficient scheduling
capacity in the proposed rehearsal.

Persistent volumes, shared stores, jobs and singleton migrations retain their
own coordination/compatibility requirements. Replicated pods do not make a
single-instance state dependency highly available.

Use the platform version's authoritative documentation, such as
[Pod lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
and [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/).
Record the observed configuration identity and source review dates. Do not
write manifests or execute cluster commands from this workflow.
