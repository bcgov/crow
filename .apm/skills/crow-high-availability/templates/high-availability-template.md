# Application maintenance continuity

## 1. Scope and evidence

{{SERVICE_BOUNDARY_AND_MAINTENANCE_SCENARIOS}}

Application releases and runtime/framework/dependency updates are assessed.
Host/OS and database-engine patching, DR and operational execution are excluded.
Record business hours/time zone, availability measurement point and denominator,
planned-maintenance treatment, operation outcomes, owners and supplied sources.
Label configuration, deployed exports, measurements and proposals separately.
Record source sections/lines, dates, confidence and missing/conflicting evidence.

## 2. Continuity contract

The JSON below is the single source for IDs and numeric criteria. Replace
placeholders; keep empty results when testing has not occurred. Do not invent
measurements to make validation pass. Empty operation/scenario/criterion arrays
are valid only for draft not-assessed/cannot-establish assessments, with gaps
explained below. An approved remediation design still needs operations,
scenarios and measurable criteria. Every declared operation/scenario pair needs
a criterion; describe unresolved scope in the gap section rather than silently
leaving a declared pair uncovered.

<!-- crow:continuity-contract -->
```json
{
  "schemaVersion": "1.0",
  "sourceRevision": "{{ASSESSED_APPLICATION_COMMIT}}",
  "service": "{{SERVICE_ID}}",
  "environment": "{{TARGET_ENVIRONMENT}}",
  "platformRevision": "{{CONFIGURATION_IDENTITY}}",
  "designStatus": "draft",
  "continuityVerdict": "designed-not-demonstrated",
  "lastConfirmed": "{{YYYY-MM-DD}}",
  "reviewAfter": "{{YYYY-MM-DD}}",
  "operations": [
    { "id": "OP-001", "outcome": "{{CRITICAL_BUSINESS_OUTCOME}}", "owner": "{{TEAM}}" }
  ],
  "scenarios": [
    { "id": "SC-001", "change": "{{MAINTENANCE_CHANGE}}", "operationIds": ["OP-001"], "runbookId": "RB-001" }
  ],
  "criteria": [
    {
      "id": "CR-001",
      "operationId": "OP-001",
      "scenarioId": "SC-001",
      "metric": "{{METRIC_AND_POPULATION}}",
      "operator": "lte",
      "threshold": null,
      "unit": "{{UNIT}}",
      "window": "{{MEASUREMENT_WINDOW}}",
      "workload": "{{REPRESENTATIVE_DEMAND_AND_CONCURRENCY}}",
      "minimumSamples": null,
      "minimumSeconds": null
    }
  ],
  "evidence": [],
  "results": []
}
```
<!-- /crow:continuity-contract -->

Evidence records use `id`, repository-relative `path`, `kind`
(`repository`, `supplied-config`, `supplied-measurement`), and `confidence`
(`Verified`, `Inferred`, `Unknown`). Supplied evidence also records
`environment`, `sourceRevision`, `platformRevision`, `capturedAt` (UTC),
and `reviewAfter` (date). Keep sensitive raw evidence outside tracked/public
content; use sanitized project-local summaries when a portable path is needed.

Result records use `criterionId`, `evidenceId`, `phase` (`before`, `during`,
`after`), numeric `observed`, `unit`, `workload`, `samples`, and `seconds`.
Record actual results only. The validator checks records, not artifact truth.

## 3. Gaps and dependencies

| Gap | Evidence/confidence | Affected IDs | Impact | Owner | Disposition |
|---|---|---|---|---|---|
| {{GAP}} | {{SOURCE}} | {{IDS}} | {{IMPACT}} | {{TEAM}} | {{BLOCKING_ADVISORY_DEFERRED}} |

Include excluded-layer dependencies and unavailable evidence. Separate missing
design inputs from known implementation/operational-verification work.

## 4. Target design and alternatives

{{COMPONENT_COMPATIBILITY_MATRIX_AND_EVIDENCE_BASED_PATTERN_DECISION}}

Address remaining capacity, state/keys/sessions/assets, health/admission,
synchronous and worker draining, long connections, scheduling, old/new
contracts, schema evolution and recovery. State N/A rationales, rejected
alternatives and assumptions with review dates.

## 5. Phased recommendations

{{OWNERS_DEPENDENCIES_SEQUENCING_ACCEPTANCE_AND_OPTIONAL_IMPROVEMENTS}}

## 6. Maintenance and recovery runbooks

### RB-001

{{SCENARIO_TARGET_VERSIONS_OWNER_PREREQUISITES_ORDERED_GATES_TIMEOUTS_ABORT_AND_POSTCHECKS}}

Include ingress/worker timelines, data sequencing, last safe rollback point,
irreversible effects and forward-recovery/escalation paths.

## 7. Verification plan and supplied results

{{CRITERION_IDS_BUSINESS_INVARIANTS_REPRESENTATIVENESS_FAILURE_CASES_AND_EVIDENCE_LIMITS}}

Describe how critical operations accepted before maintenance are reconciled
through completion. Include lost/duplicate effects, latency, sessions and
asynchronous delay. Successful deployment or healthy instances is insufficient.

## 8. Handoffs and decisions

{{CONSUMER_SCOPES_APPROVALS_AND_ACCEPTED_LIMITS}}

Record owner-approved interruption, approval date, `last_confirmed` and
`review_after`. Handoffs are draft until explicitly signed off; design sign-off
does not authorize implementation/deployment or demonstrate continuity.

## 9. Open and resolved items

{{BLOCKING_ADVISORY_DEFERRED_ITEMS_AND_DATED_RESOLUTIONS}}

When unsupported, state: the requested continuity cannot be established.
Otherwise qualify demonstration to the recorded environment, application and
platform versions, scenarios, workload and time; never promise future uptime.
