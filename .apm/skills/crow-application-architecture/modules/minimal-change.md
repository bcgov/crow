# Minimal-change decision guide

Use this guide when choosing whether to add code, an abstraction, a dependency,
or a new boundary. It applies after understanding the affected behavior and
tracing the real flow.

## Decision ladder

Stop at the first option that satisfies the requirements:

1. Do we need this capability or change at all? Remove speculative work.
2. Does the codebase already provide it? Reuse the existing helper, type, pattern, or boundary.
3. Does the standard library provide it?
4. Does the native platform or framework provide it?
5. Does an already-installed dependency provide it?
6. Otherwise, write the smallest custom implementation that remains clear,
   testable, maintainable, and correct at its trust boundaries.

The ladder is a decision aid, not a mandate to choose a shorter implementation.
Choose a more capable option when requirements, security, accessibility,
supportability, compliance, platform alignment, performance, or real-world
calibration justify it. Record the requirement and rejected simpler options.

## Safety invariants

Minimalism must not remove:

- validation at trust boundaries or invariants where state changes;
- authentication, authorization, least privilege, or protected-resource checks;
- error handling needed to prevent data loss or success-shaped failure;
- accessibility, Unicode, localization, or degraded-state behavior;
- cancellation, deadlines, bounded retries, idempotency, or dependency failure
  behavior;
- required auditability, telemetry, contract compatibility, or rollback behavior;
- a focused runnable check for non-trivial logic, security paths, parsers, money
  calculations, or boundary behavior.

## Smallest sufficient check

For trivial declarative or pass-through changes, do not create test
infrastructure solely to satisfy a rule. For non-trivial logic, leave one
focused check at the lowest level that can catch the defect. Add broader tests
only when a real boundary or risk requires them.

## Deliberate debt

When a simplification deliberately accepts a known ceiling, record it in a
comment using this form:

```text
# crow-debt: shortcut; <what was simplified>; ceiling: <known limit>; revisit: <measurable trigger>; owner: <team>
```

Use the matching comment prefix for the language. The `type` may identify
future debt classes such as `legacy-library` or `modernization`. Do not use the
marker for ordinary implementation choices with no known ceiling.
