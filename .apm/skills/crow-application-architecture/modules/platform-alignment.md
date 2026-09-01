# Platform alignment and reuse

This module is technology-neutral. Load it only when an application consumes, provides, or may replace a shared capability, canonical register, public service, or external integration, or when an architecture review identifies one-to-many impact.

Apply the principles below to the evidence in the current repository; do not infer a platform role from naming alone. Keep archived business rules with each project's documentation; do not centralize or rewrite them as part of platform alignment.

## Conditional role classification

Select exactly one role when evidence supports it:

| Role | Meaning |
|---|---|
| **Public service** | A capability intentionally exposed to members of the public or external organizations. |
| **Shared platform** | A reusable capability or service used by multiple products or teams. |
| **Canonical register** | The authoritative source for a defined set of records or attributes. |
| **Internal system** | A system primarily serving one organization or controlled operating group. |
| **Point solution** | A focused solution with no evidenced shared-service or canonical-register responsibility. |
| **Integration adapter** | A boundary component whose primary responsibility is translating or brokering between systems. |

Record the evidence, confidence, intended consumers, and the consequences of
being wrong. If the evidence is insufficient, record `Unknown` rather than
choosing a role.

## One-to-many impact and reuse

- Identify whether a change affects one consumer or many consumers. A
  one-to-many dependency needs explicit compatibility, notification, support,
  capacity, and rollback considerations.
- Prefer an existing approved shared capability when it satisfies the need.
  When no shared-service catalogue exists, record the discovery sources
  checked, the candidate owner, consumer constraints, and the evidence for
  reusing or not reusing the capability. Do not invent a catalogue or
  catalogue entries.
- A shared boundary must have an accountable owner, an operating objective,
  consumer support expectations, and a documented change path.

## Data custodianship and purpose

For each shared or canonical data flow, identify:

- the authoritative source and data custodian;
- the permitted purpose, subject/tenant scope, sensitivity, retention, and
  access decision;
- whether the data is **open**, **shared**, or **closed**, with evidence for
  the classification and any conditions on reuse.

Prefer a narrow question API that returns the decision or minimum answer
needed for a purpose over a broad data API or replicated dataset. A consumer
must not request, cache, log, or persist fields it does not need. Subject and
purpose scope must be enforced by the provider, not inferred from a UI.

## Contracts and evolution

Every externally consumed API, event, file, or proof contract needs an
identified owner and:

- an explicit schema and compatibility policy;
- versioning, deprecation, consumer notification, and migration expectations;
- ownership of validation and error semantics;
- expand/migrate/contract sequencing where mixed versions can coexist;
- a tested rollback or compatibility escape route.

Do not share mutable persistence models or internal exceptions as a public
contract.

## Dependency degradation

For every critical dependency, define and test deadlines, cancellation,
bounded retries, idempotency, backpressure, and retry exhaustion. State
whether the consumer fails closed, queues work, serves clearly marked stale
data, or uses an assisted/manual path. A fallback must not silently weaken
authorization, identity assurance, data minimization, or auditability. Expose
staleness and decision provenance where users or operators need it, and never
turn an unavailable dependency into a false success.

## Review record

Capture the following in architecture or design documentation:

| Decision | Evidence / owner | Confidence |
|---|---|---|
| Role classification and one-to-many impact | | `Verified / Inferred / Unknown / N/A` |
| Reuse or build decision and discovery performed | | `Verified / Inferred / Unknown / N/A` |
| Data custodian, purpose/subject scope, and sharing spectrum | | `Verified / Inferred / Unknown / N/A` |
| Contract owner, version, compatibility, and rollback | | `Verified / Inferred / Unknown / N/A` |
| Dependency degradation and observable audit/provenance | | `Verified / Inferred / Unknown / N/A` |
