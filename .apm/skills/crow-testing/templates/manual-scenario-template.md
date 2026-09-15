# [Feature or area] Manual QA scenarios

<!--
Recurring manual-QA scope for one feature, bug, or manual-QA area.
This document says what QA should test. Execution and run evidence are tracked outside the repository.
Omit any field below that doesn't apply to this document instead of writing N/A.
-->

## Overview

| Field | Value |
|---|---|
| Area ID | `MC-XXX` — index: `docs/testing/manual-coverage.md` |
| Classification | Manual-only / Deferred automation |
| Status | Draft / Current / Needs decision |
| Default release trigger | Every release / When <component> changes / Smoke only |
| Related work item | `None`, `DRAFT-*`, `Existing - <ID/link>`, or `Created - <provider>:<ID>` |
| Open decisions | Short list or `None` |

## Scope and automation rationale

- **In scope:** ...
- **Out of scope:** ...
- **Why manual:** ...
- **Representative sample (omit if not a shared UI element):** <page/component> @ <relative route> —
  reason chosen

## Prerequisites and test setup

- **Environment:** ...
- **Page(s)/route(s) to test:** <relative path(s), e.g. `/settings/profile`> — start point (omit only when
  the behavior has no navigable page).
- **Role/permissions (omit if the outcome doesn't vary by role):** ...
- **Pre-seeded data/state (omit if no special setup is required):** ...
- **External dependencies (omit if none):** ...

## Test matrix

| ID | Scenario | Precondition / variant | Expected outcome | Release trigger |
|---|---|---|---|---|
| MC-XXX-01 | | | | Default / Smoke / Full |

If scenarios start on different pages, add a `Page/route` column to the matrix instead of relying on the
shared "Prerequisites" field.

## Detailed scenarios

### MC-XXX-01 — Short scenario name

1. ...
2. ...

**Expected result:**

- ...

## Recheck and automation triggers

- **Recheck when:** ...
- **Automate when:** ... (omit if permanently manual-only)
