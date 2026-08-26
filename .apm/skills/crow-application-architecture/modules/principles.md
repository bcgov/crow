# Technology-independent architecture principles

## Prefer the smallest sufficient architecture

- Start with one deployable application unless independently scalable, independently released, or separately governed components justify distribution.
- Prefer a modular monolith over premature microservices. Enforce module boundaries in code so extraction remains possible.
- Make every boundary earn its operational cost. A network boundary adds latency, failure modes, authentication, authorization, versioning, telemetry correlation, and deployment coordination.

## Separate responsibilities without ceremonial layers

- Keep delivery concerns at the edge: HTTP, messaging, scheduling, CLI, and UI adapt external input into application operations.
- Keep business rules independent of web frameworks, persistence libraries, and transport DTOs where their complexity warrants isolation.
- Put infrastructure implementations behind dependency inversion when there is a real external dependency or test seam.
- Do not create pass-through projects, repositories, or services that add naming but no policy, abstraction, or replaceable behavior.
- Dependencies point inward toward stable policy. Domain/application code must not depend on delivery or deployment projects.

## Design explicit boundaries

For each module or service, define:

- owned behavior and invariants;
- public operations and versioning expectations;
- allowed dependencies;
- trust boundary and authorization policy;
- failure, retry, timeout, and idempotency behavior;
- telemetry emitted without secrets or sensitive payloads;
- deployment and rollback unit.

Use contracts at boundaries. Do not share mutable persistence models, framework request objects, or internal exceptions across them.

## Cross-cutting concerns are architecture

- Authenticate at the edge and authorize every protected operation and resource.
- Validate untrusted input at the boundary and enforce invariants again where state changes.
- Propagate cancellation and deadlines through external calls.
- Define readiness separately from liveness; readiness may include critical dependency checks, while liveness must not create cascading failure.
- Use structured logs, metrics, and distributed traces with correlation identifiers. Redact sensitive data before it reaches a telemetry sink.
- Keep secrets outside source and ordinary configuration files. Prefer workload/managed identity over long-lived credentials.
- Make configuration errors fail startup outside local development rather than silently weakening security.

## Evolution and verification

- Prefer reversible decisions, stable public contracts, and additive change.
- Test architectural rules where practical: dependency direction, authorization defaults, serialization contracts, and startup configuration.
- Correlate artifacts with source commits and produce immutable, repeatable builds.
- Document exceptions with an owner, rationale, risk, and review date.

