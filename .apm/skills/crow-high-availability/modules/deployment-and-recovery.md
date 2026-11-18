# Pattern selection, maintenance and recovery

Apply the [minimal-change decision ladder](../../crow-application-architecture/modules/minimal-change.md).
Do not change hosting merely to fit a favourite deployment pattern. General
hosting selection belongs to the
[Solution Architecture Agent](../../../agents/crow-solution-architecture.agent.md).

## Select from observed capabilities

| Candidate | Establish before recommending |
|---|---|
| Sequential instance replacement | Independent routing/admission and draining, adequate remaining capacity, warm-up, compatible overlap and worker coordination |
| Parallel environments / blue-green | Duplicate capacity, compatible shared or synchronized state, safe isolated warm-up, controlled switch, old-client support and valid reversal |
| Canary / progressive exposure | Appropriate traffic cohorts, representative operation signals, sufficient observation/sample size, bounded side effects and explicit abort decisions |
| Managed slots or revisions | Actual tier/version features, swap/settings/identity behavior, readiness, quotas, long-connection behavior and reversal limitations |
| Bounded interruption | Evidence that stronger continuity is infeasible under present constraints, plus explicit owner acceptance of the measurable interruption and consequences |

Record prerequisites, rejected alternatives, cost/operational constraints,
residual risk, accountable team, evidence confidence and revisit trigger.
Canary exposure does not make an incompatible schema or irreversible side
effect safe. No alternate capacity or routing control may mean the requested
continuity cannot be established.

## Phased recommendations

Separate blocking design inputs from known implementation gaps:

1. Resolve objectives, compatibility questions and dependency ownership.
2. Implement the minimum approved controls through existing specialists.
3. Rehearse under representative traffic and adverse conditions.
4. Obtain operational readiness decisions; consider optional improvements.

For each recommendation give owner, dependencies, affected operation/scenario
and criterion IDs, acceptance evidence and sequencing. An urgent fix is not
blocked on adopting this capability.

## Runbook contract

Create one `RB-` runbook per `SC-` scenario. Each includes:

- target service, application/runtime/platform versions, owner, permissions,
  approved artifact identity, dependencies, capacity and compatibility checks;
- ordered actions with preconditions, observable completion gates, decision
  owner, timeout, abort threshold and evidence to retain;
- schema expansion/backfill/validation ordering and a single migration
  coordinator where needed, separate from ordinary replica startup;
- ingress routing removal/propagation, active-request drain, worker acquisition
  stop and active-job recovery, bounded long-connection handling and warm-up;
- criteria monitored before, during and after maintenance, including critical
  business outcomes, latency, retries and asynchronous completion;
- last safe rollback point and application/data compatibility afterward;
  irreversible writes, events and external effects; forward recovery or
  compensating/reconciliation paths where reversal is unsafe;
- incident escalation, abort/restore decision, post-checks and residual work.

These are reviewed procedures, not executed maintenance. Do not embed runnable
deployment or DDL scripts. A database restore is not a zero-loss rollback and
does not establish uninterrupted application service.
