# Module: Finding Synthesis and Validation

**Purpose:** Reconcile independently validated findings, identify systemic
themes, form evidence-backed attack paths, and prioritize affected components
without changing source finding severity.

Load this module after the domain review produces at least two findings that
share a root control, workflow, protected resource, or attacker path.

## Validation adjudication

Before synthesis, independently re-check each Critical and High finding and
every source finding used by a proposed chain. Record one disposition:

- `Confirmed`
- `PartiallyConfirmed`
- `Disputed`
- `Rejected`
- `Unknown`

When validation changes severity, scope, preconditions, or causal language,
resolve the difference as `Accepted`, `Adjusted`, or `Removed`. `Pending`
resolution blocks finalization. Recalculate report counts after adjudication;
do not leave corrections only in a validation note.

Negative claims require the searched scope, excluded paths, unavailable
external systems, and the evidence supporting absence. Source-code absence
cannot prove identity-provider, gateway, hosting, or organization-level
configuration.

## Cross-cutting themes

Group findings only when they share an evidenced systemic cause or control
failure. A theme must cite findings from at least two domains or two distinct
architectural layers. Do not create a theme from shared severity, CWE, file, or
keyword alone.

Distinguish:

- duplicate findings that describe the same defect; and
- duplicated security decisions independently implemented at multiple
  enforcement points, which create divergence and partial-fix risk.

## Attack-path chains

A chain requires:

1. at least two distinct, active source findings;
2. a plausible attacker-controlled entry point or protected-state trigger;
3. ordered steps;
4. direct evidence for every edge;
5. explicit preconditions with `Verified`, `Inferred`, or `Unknown` status;
6. greater combined impact than any source finding alone.

Allowed edge types are `contributes-to`, `root-cause-of`, and `related-to`.
Reject a chain when the relationship is only a shared component, tag, severity,
or duplicate description.

Chain risk and confidence are separate from source-finding severity. Never
promote source severities or overall report risk because a chain exists. A
chain depending on an unknown deployment or external-system precondition
cannot be presented as an unqualified confirmed attack path.

## Deterministic synthesis

Create the synthesis input described by
`scripts/New-CrowSecuritySynthesis.ps1`, then run the script. It:

- applies resolved validation adjustments;
- removes rejected findings from active counts;
- generates stable chain IDs from ordered source IDs;
- validates chain edges, evidence, and preconditions;
- calculates component remediation-priority scores;
- emits the canonical counts used by report frontmatter.

Each evidence record requires string `id`, `path`, and `summary` values plus a
positive `startLine` and an `endLine` no earlier than it. Paths must be
repository-relative and contain no root, empty, `.` or `..` segments; the
script does not verify file existence. The output preserves validated records
under `evidence`, so consumers resolve each chain `evidenceRefs` value against
`evidence[].id`.

Run `scripts/Test-CrowSecurityReviewOutput.ps1` after writing the report. A
count mismatch, unresolved adjudication, missing finding/chain identifier, or
missing synthesis section is a failed review.

## Component priority model

The `crow-v1` score ranks remediation concentration; it is not vulnerability
severity and has no cap or severity-band conversion.

For each component:

```text
base = sum(severity_weight * confidence_weight for each unique active finding)
breadth = 1 + min(0.5, 0.1 * (distinct_domains - 1))
exposure = External 1.25 | CrossService 1.15 | Internal 1.0
priority = round(base * breadth * exposure, 1)
```

Severity weights are Critical `16`, High `8`, Medium `4`, Low `1`, and
Informational `0`. Confidence weights are Confirmed `1.0`, Probable `0.5`, and
Informational `0`. Chains are excluded to prevent double counting their source
findings. The breadth factor plateaus at `1.5` when six or more distinct
security domains affect the component.

Use scores only for relative ordering within the same assessment. They are not
percentages, thresholds, or comparable severity bands across repositories.
After ordering, consider dependencies, effort, and compensating controls
separately.
