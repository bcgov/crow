# Verification, verdicts and scoped handoffs

## Criteria and supplied results

Use stable `OP-`, `SC-`, `CR-`, `RB-`, `EV-` identifiers from the report's single
structured contract. Each applicable operation/scenario pair needs a criterion;
split criteria when latency, errors, loss, duplication or completion have
different limits. Exclude a pair only by removing it from the scenario's
`operationIds` and recording the owner-approved rationale in the narrative.

Each criterion records metric, comparator (`lte`, `gte`, `eq`), numeric
non-negative threshold, unit, measurement window, representative workload,
minimum sample count and minimum observation seconds. Document the SLI
population/denominator, business outcome and integrity invariant in narrative;
do not hide failed attempts through retries or averages.

Plan before/during/after observations under representative traffic, including
peak or justified demand, reduced capacity, warm-up, mixed versions, existing
sessions, in-flight work, long-lived connections and queued jobs. Include failed
readiness/replacement, forced termination, retry amplification, scheduler
overlap, schema/backfill pressure and recovery where applicable. Synthetic or
sanitized data only; never replay production payloads.

The [Testing Agent](../../../agents/crow-testing.agent.md) owns approved API/service
scenarios and test implementation. Platform/application operators own approved
traffic tooling, maintenance execution and operational rehearsal. Browser-only
behavior requires an explicit manual check or separately scoped owner; do not
expand Crow Testing into browser E2E or claim complete user-journey coverage
from API checks.

Only supplied measurement artifacts can support `demonstrated`. For every
criterion require before/during/after result records with matching units and
workload, sufficient samples/duration, observed values meeting thresholds, and
Verified evidence with matching environment, assessed application revision,
platform configuration identity, capture date and an unexpired review date.
Include those platform/version identities in the evidence itself; verify the
record against it. Results must include work accepted before maintenance and
eventual business effects. Healthy probes or a completed pipeline are not
substitutes. Source/configuration drift or a new contradiction reopens the claim.

The validator checks these record relationships and numeric comparisons, not
the truth, representativeness, independence or completeness of an export.

## Three separate lifecycles

| Concept | Meaning |
|---|---|
| Run status | Canonical complete / partial / blocked / failed; applies to the assessment/design task and its checks |
| Design approval | draft / approved in the report; draft / signed-off in a requested consumer handoff, with explicit user approval |
| Continuity verdict | not-assessed / cannot-establish / designed-not-demonstrated / demonstrated |

A complete approved design may remain designed-not-demonstrated. Missing
operational tests alone are a known implementation/verification gap, not an
omission preventing a testing handoff. A cannot-establish verdict may accompany
an approved remediation design when prerequisites, limits and work are explicit.
Missing facts required to design that work remain Blocking; do not downgrade
them just to sign off.

An approved design cannot be not-assessed and must include critical operations,
maintenance scenarios and measurable criteria even when its verdict is
cannot-establish. A draft assessment may leave the structured scope empty while
recording missing decisions in its gap section. Any declared operation/scenario
pair requires a criterion regardless of verdict.

Say "the requested continuity cannot be established" when objectives, capacity,
compatibility, dependencies or representative results do not support it.
`demonstrated` means only the recorded scenario/environment/version/load/time
boundary, never a future or unconditional guarantee.

## Handoff envelope and owners

Follow the canonical [handoff contract](../../crow-agent-skill-authoring/modules/interaction-contracts.md#handoff-contract).
Use one schema; generate a separate
`high-availability-<consumer>-handoff.json` beside the report for each requested
consumer. Facts retain Verified/Inferred/Unknown confidence and evidence
paths. Record N/A only in narrative with a reason.

| Consumer ID | Permitted work kind | Owning workflow |
|---|---|---|
| crow-data-architecture | data-model-change | [Data Architecture](../../crow-data-architecture/SKILL.md): schema/mapping/migration design and implementation; no shared-database execution |
| crow-ci-pipelines | pipeline-configuration | [CI Pipelines](../../crow-ci-pipelines/SKILL.md): approved repository controls within existing provider boundaries |
| crow-framework-dependency-update | runtime-dependency-update | [Framework](../../crow-framework-updates/SKILL.md) / [dependency updates](../../crow-dependency-updates/SKILL.md): preserve these continuity constraints; owner still selects and verifies versions |
| crow-testing | service-tests | [Testing](../../crow-testing/SKILL.md): reviewed API/service scenarios, no implicit traffic or deployment authority |
| crow-application-development | application-change | [Application Development](../../crow-application-development/SKILL.md): normal coding agent, not an invented agent |

The template's excluded actions are mandatory. Never request deployment,
traffic execution, host/OS or database-engine patching through this handoff.
Prose must match the validated work kind; a valid enum is not permission to
smuggle broader work into its summary.

Before generating/building from a handoff, the consumer runs the
[validator](../scripts/Test-HighAvailabilityOutput.ps1) in Handoff mode with
`-RequireSignedOff -ExpectedConsumer <its-id>`. It checks the report, references,
sign-off, and Git ancestry plus changes to all listed artifacts/evidence.
The handoff itself is excluded from revision drift. Commit reviewed artifacts
before recording the handoff's `sourceRevision`; the report's assessed
application revision may be earlier. Explicit user acceptance can permit
documented revision drift, never invalid evidence or unsupported claims.

Add a conditional guard to a consumer, not a second workflow. A draft can be
reviewed only. Never auto-run consumers, mark sign-off from file existence, or
treat design approval as authorization to build, test a shared target or deploy.
