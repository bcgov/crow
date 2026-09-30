# Security Architecture Handoff

Use this module when the architecture review produces the compact
`architecture-security-facts.json` sidecar consumed by the security review
workflow.

## Output paths

- Single application: `docs/architecture-security-facts.json`
- Monorepo service: `docs/<service-name>/architecture-security-facts.json`

The sidecar supplements `architecture.md`; it does not replace the human-facing
document. Emit one sidecar per architecture document. Do not create a combined
monorepo handoff.

## Content boundary

Include only security-relevant architecture facts that reduce rediscovery:

- identities and authentication mechanisms;
- protected resources and trust boundaries;
- privileged operations and enforcement points;
- credential or token flows;
- externally controlled inputs;
- sensitive persistence stores;
- background or scheduled security behavior;
- end-to-end workflows that cross a trust boundary or change protected state;
- unresolved architecture questions that materially affect security analysis.

Do not copy component inventories, dependency lists, prose explanations, code
snippets, or vulnerability findings into the sidecar. Security conclusions
belong to the security review.

## Contract

Start from
[`../resources/security-handoff-template.json`](../resources/security-handoff-template.json).
Use repository-relative paths and stable IDs:

- `AF-###` for facts;
- `WF-###` for workflows;
- `EV-###` for evidence;
- `U-###` for unresolved questions.

Normalize evidence in the top-level `evidence` array and reference it through
`evidenceRefs`; do not repeat paths and line ranges in every fact. Keep summaries
short enough to identify the security significance without reproducing source.

Every fact requires a confidence of `Verified`, `Inferred`, or `Unknown`.
`Verified` requires direct source or configuration evidence. `Inferred` and
`Unknown` facts are discovery hints, not proof of a security finding.

For each security-relevant workflow, record:

- trigger and actor;
- ordered components and actions;
- trust-boundary or protected-state transitions;
- authentication, authorization, validation, audit, and test controls;
- failure or degradation behavior;
- evidence references.

Use an empty array when a control was inspected and none was evidenced. Use an
`unknowns` entry when the repository cannot establish an external or deployment
fact.

## Freshness and validation

Set `sourceRevision` to the inspected Git commit and `generatedAt` to an ISO
8601 UTC timestamp. The security review may trust `Verified` facts only when
`sourceRevision` matches the reviewed revision. A stale handoff remains a
discovery hint and every material fact must be re-verified.

Run `Test-ArchitectureOutput.ps1` with `-RequireSecurityHandoff` during
post-write validation. A missing or invalid required handoff is a failed
architecture review.

Schema validity does not prove freshness or evidence confidence. The consuming
security review must compare `sourceRevision` with the current commit and
re-verify every `Inferred` or `Unknown` fact.
