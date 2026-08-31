# Repository Classification

Classify the repository before selecting an architecture output path. Bounded manifest and deployment inspection is permitted during classification; defer deeper architecture analysis and all writes until classification is complete.

## Classification signals

Treat the repository as a monorepo when it contains multiple independently deployable applications or services, as evidenced by one or more of:

- manifests such as `package.json`, `.csproj`, `go.mod`, `pom.xml`, or `Cargo.toml` in separate application subtrees;
- workspace or solution configuration referencing distinct deployable projects;
- Docker Compose or Kubernetes definitions for distinct services;
- separate container or process entry points with independent deployment lifecycles.

Multiple libraries or test projects alone do not make a repository a monorepo.

## Single-application contract

Write one document to `docs/architecture.md`.

## Monorepo contract

Build a complete inventory of independently deployable services before deeper inspection. Each inventory record must contain:

```json
{
  "name": "orders",
  "sourcePath": "services/orders",
  "manifestPath": "services/orders/package.json",
  "deploymentEntryPoint": "services/orders/Dockerfile",
  "outputPath": "docs/orders/architecture.md"
}
```

Names and output paths must be unique. Every output path must have the form `docs/<service-name>/architecture.md`.

Write exactly one service-scoped document per inventory record and a root `docs/architecture-index.md`. The index must link every service document and describe shared infrastructure and inter-service communication. A monorepo must not contain `docs/architecture.md`.

Stop with a visible error when service discovery is incomplete or ambiguous, any inventory field is missing, output paths conflict, or a root `docs/architecture.md` exists.
