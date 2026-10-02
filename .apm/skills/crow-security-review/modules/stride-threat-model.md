# Module: STRIDE Threat Modeling

**Purpose:** Produce an evidence-backed STRIDE assessment that can be
reconciled between the security review and downstream executive reports.

Apply this module to every service review. Assess key components and trust
boundaries across all six categories:

| Category | Threat question |
|---|---|
| Spoofing | Could an actor or component impersonate another identity? |
| Tampering | Could data, configuration, or security state be modified without authorization? |
| Repudiation | Could a security-relevant action occur without attributable evidence? |
| Information Disclosure | Could information be exposed outside its authorized purpose or audience? |
| Denial of Service | Could a resource or function be disrupted or exhausted? |
| Elevation of Privilege | Could an actor gain authority beyond its intended permissions? |

## Rating rules

Use one qualitative rating for every category in every row:

- `High`, `Medium`, or `Low` for an evidenced threat exposure in the reviewed
  scope.
- `Unknown` when the available evidence cannot support a rating. Unknown is
  not Low.
- `N/A` only when the category does not apply to that component; explain why.

Ratings are not finding severities, likelihood scores, CVSS, or a numeric risk
model. Do not derive them from finding counts or severity. A conditional threat
must retain its deployment, identity-provider, or other precondition in the
rationale; do not turn an unknown precondition into a confirmed exploit.

## Required security-synthesis data

New synthesis input uses `schemaVersion: "1.1"` and contains a non-empty
`stride` array. Each row has this shape:

```json
{
  "component": "Identity and administrator boundary",
  "S": "High",
  "T": "Medium",
  "R": "Unknown",
  "I": "Low",
  "D": "Low",
  "E": "High",
  "evidenceRefs": ["EV-001"],
  "rationale": "High spoofing and elevation exposure depends on the verified source behavior and the stated external precondition."
}
```

Use the exact rating values above. Each component must be unique and have
non-empty rationale plus at least one unique `evidenceRefs` entry that
resolves to an evidence record in the same synthesis input. Evidence IDs must
be strings matching `^[A-Za-z0-9][A-Za-z0-9._-]*$`; this keeps them safe as
Markdown table cells. Do not include Markdown pipes or line breaks in
component names or rationales because these values are rendered as table
cells.

Populate Section 11 of `security-review.md` from the same rows, including all
six ratings, evidence IDs, and rationale. Do not leave the matrix blank or
represent it only as prose. `New-CrowSecuritySynthesis.ps1` validates and
preserves the structured rows; `Test-CrowSecurityReviewOutput.ps1` requires
the Markdown table to match the JSON matrix exactly. A missing matrix,
unresolved evidence reference, or mismatch blocks report completion.

## Legacy synthesis compatibility

Schema `1.0` remains readable for existing reviews but has no structured
`stride` array and must not contain a `stride` property. Do not rewrite old
data or infer the missing matrix from prose. For a v1.0 review, retain ratings
only from a complete legacy seven-column Section 11 table; identify that it
has no row-level evidence IDs or rationale. All new security reviews must
emit schema `1.1` and the evidence-backed nine-column table above.

The Crow Executive Summary Report Agent copies the ratings from the validated
`security-review-synthesis.json` into `report-data.json`. It must not infer
ratings from a prose summary. If a legacy review has no structured synthesis,
use only a complete STRIDE table; otherwise stop and request an updated
security review. Run the executive report's source-to-STRIDE validator before
rendering so report-data ratings cannot drift from the source.
