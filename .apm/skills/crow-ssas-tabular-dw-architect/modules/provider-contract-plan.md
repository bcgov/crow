# Live SQL/SSAS provider contract plan

This is a planning document, not an implemented capability. It exists so the
source project's live discovery behavior is not lost when
`C:\Projects\CopilotDWTools` is retired: a reviewed provider contract must be
delivered against this plan before live discovery is claimed as supported in
Crow.

## Capability being replaced

The source `sql-dw-dimensional-review` skill used live access for:

- Mode A/E: live SQL Server row counts, `sys.*`/INFORMATION_SCHEMA metadata,
  sample rows, null/duplicate rates, and FK validation against live data.
- Mode B: live SSAS Tabular DMV queries (`$SYSTEM` schema) for processed
  state, partition health, and relationship/measure inventory beyond BIM/TMDL.
- Mode O: live execution-plan or index-usage evidence for physical-design
  review.
- Mode P: live profiling as an alternative to Path A/B/C static evidence.

## What a reviewed provider contract must define before use

1. **Tool/API identity**: the exact connection mechanism (for example, an
   MCP SQL/SSAS tool) — never an invented tool name or endpoint.
2. **Authentication boundary**: how credentials are supplied and scoped;
   Crow agents must not request, store, or embed credentials.
3. **Allowed operations**: an explicit allow-list (for example, read-only
   `SELECT`/DMV queries) with any write, DDL, or administrative operation
   excluded unless separately approved.
4. **Error and unavailability behavior**: what the agent does when the
   provider is unreachable, denies access, or returns partial results —
   must fall back to the existing local-evidence paths (Path A/B/C, BIM/TMDL
   inspection) rather than fabricate values.
5. **Freshness semantics**: how a caller distinguishes a live value from a
   static/inferred one in output (label live results explicitly; do not
   silently upgrade an inferred value's confidence).
6. **Confirmation gate**: a required user confirmation before a live query
   runs against a named environment, distinguishing lower-risk read-only
   profiling from any higher-risk operation.
7. **Scope limits**: row/sample caps, timeout, and no cross-environment
   scans without explicit target confirmation.

## Acceptance criteria for "reviewed"

A contract is reviewed (not just drafted) when it has: a named owner, a
security/architecture sign-off, and at least one worked example per mode
(A, B, E, O, P) showing the tool call, the confirmation prompt, and the
resulting labeled output. Until then, `provider-boundaries.md` continues to
list live SQL/SSAS discovery as **Deferred**.

## Status

Planned, not started. No tool, API, or timeline is committed yet. This plan
is the explicit record that live-discovery loss is a tracked pre-retirement
item, not a silent omission.
