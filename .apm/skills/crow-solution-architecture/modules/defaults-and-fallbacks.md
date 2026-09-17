# Preferred architecture and technology defaults

These are starting points, not mandates. Existing supported systems, approved
platform constraints, team capability, data sensitivity, interoperability,
and total cost can justify a fallback. Record the evidence and consequence.

## Architecture defaults

| Concern | Preferred default | Use a fallback when | Typical fallback and consequence |
| :--- | :--- | :--- | :--- |
| Deployment shape | One deployable modular monolith with enforceable internal boundaries | Components need independent scaling, release cadence, ownership, isolation, or regulatory boundaries | Separately deployable services; accept distributed security, reliability, observability, contract, and operational costs |
| User experience | Server-rendered accessible web experience for form and workflow services | Rich client state, offline behavior, high-frequency interaction, or reusable client surfaces are material requirements | SPA or client application; add API security, state, caching, compatibility, and accessibility obligations |
| Synchronous integration | Versioned REST/HTTP with OpenAPI and bounded timeouts | Streaming, durable asynchronous completion, fan-out, or temporal decoupling is required | Brokered events or queues; add schema ownership, idempotency, ordering, replay, poison-message, and monitoring design |
| Background work | In-process scheduled/background work for low-volume non-critical tasks | Work must survive process restarts, scale independently, or complete after long delays | Durable queue and worker; add delivery semantics, deduplication, backpressure, and recovery |
| Data ownership | One transactional store owned by the application boundary | Distinct data products, scale, retention, search, analytics, or isolation needs are proven | Purpose-specific stores; avoid distributed transactions and define consistency and reconciliation |
| External capability | Reuse an approved common component behind an application-owned adapter | Eligibility, assurance, capability, support, availability, cost, or roadmap does not fit | Alternate shared service or smallest custom capability; document ownership and exit or migration plan |

## Preferred application stack

Current public B.C. developer guidance lists C# and .NET alongside Python,
JavaScript or TypeScript, Java, R, and PHP and requires teams to select
technology for their own context.

| Layer | Preferred starting point | Constraint-driven fallback |
| :--- | :--- | :--- |
| Backend | Current supported .NET LTS with ASP.NET Core, nullable reference types, analyzers, OpenAPI, and structured telemetry | Current supported Java LTS with Spring Boot for an established JVM estate; TypeScript on a supported Node.js LTS for a JavaScript or TypeScript operating model; Python on a supported release for data, automation, or AI workloads with appropriate production controls |
| Web UI | ASP.NET Core Razor Pages or MVC for workflow-heavy forms; Blazor when a .NET client model is an intentional fit | React or Vue with TypeScript for complex client interaction and an established frontend team; standards-based Web Components for small embeddable surfaces |
| Transactional data | The ministry-supported relational platform; prefer PostgreSQL for portable cloud-native workloads and SQL Server when Microsoft integration, existing operations, or migration constraints dominate | A specialized document, graph, time-series, search, or analytical store only for a demonstrated access pattern |
| API | REST/JSON over HTTPS with OpenAPI and additive versioning | gRPC for controlled high-throughput service calls; GraphQL for demonstrated multi-client query needs; asynchronous contracts for durable decoupling |
| Hosting | Select among supported data-centre, private-cloud, public-cloud, and SaaS options from workload, data, resilience, integration, cost, and operational evidence | Revisit when classification, capacity, latency, CPU, bandwidth, I/O, support, managed-service, or procurement requirements change |
| Delivery | Select among virtual machines, containers, platform-native, serverless, and managed delivery based on runtime, performance, compatibility, scaling, recovery, and ownership requirements | Revisit when the selected delivery unit no longer satisfies release, scaling, isolation, support, or recovery needs |

Never select a runtime version solely because this module names a technology.
At design time verify support status, hosting compatibility, data
classification limits, security update policy, team supportability, and
migration path. Pin versions in the consuming solution, not in this reusable
guidance.

Use the bundled hosting-choices template to compare benefits and drawbacks.
Data-centre hosting and virtual machines are first-class choices and do not
require a modernization path solely because they are selected.

## Selection record

For each major choice record:

| Decision | Default considered | Constraint or evidence | Selected option | Fallback trigger | Consequence | Owner | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| | | | | | | | `Confirmed / Provisional / Rejected / Blocked` |

Do not list several stacks as equally recommended. Select one for the current
constraints and preserve a bounded fallback.
