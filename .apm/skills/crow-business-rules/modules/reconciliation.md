# Reconciliation With Documentation

Reconciliation compares each extracted rule with the guides, training material,
specifications, and policies that were actually available for this run.

## Documentation inventory

Record every source in `documentation_sources` with its kind, location, and
status:

- `available` sources were read during this run;
- `unavailable` sources are known to exist but could not be inspected.

Ask the report user once for guides or training documents when none were
supplied and none are discoverable in the repository. Do not block the run on
the answer.

## Reporting a documentation gap

When documentation is missing, unavailable, or clearly stale, set
`documentation_gap.present` to `true` and record:

- `summary` - what was missing or could not be read;
- `coverage_impact` - which conclusions are weaker as a result.

The validator requires this whenever there are no sources or any source is
`unavailable`, so a reduced-coverage run cannot be presented as a complete one.
Continue the run and report the gap; do not silently downgrade rules.

## Classifications

| Classification | Use when | Required evidence |
|---|---|---|
| `aligned` | implementation and documentation agree | at least one citation and at least one documentation reference whose source status is `available` |
| `implemented-only` | the code enforces a rule no available document describes | at least one citation and a note |
| `documented-only` | documentation states a rule that the reviewed code does not implement | at least one documentation reference and a note |
| `conflicting` | code and documentation state different outcomes | citations, at least one `available` documentation reference, and a note describing both positions |
| `unverifiable` | evidence was insufficient to decide | the evidence that was inspected and a note explaining the limit |

Rules:

- Do not classify a rule as `aligned` because it looks reasonable. Alignment
  requires a document that says the same thing.
- `aligned` and `conflicting` are comparisons, so the validator requires a
  documentation source with `status: available`. A source that could not be
  inspected cannot support either claim; use `unverifiable` with a note that
  names the uninspected source instead.
- Do not classify a rule as `documented-only` before checking configuration,
  migrations, scheduled jobs, and other services in scope.
- `conflicting` is a finding, not an error. State both positions neutrally and
  do not pick a winner.
- Use `unverifiable` rather than guessing when indexing coverage was partial,
  source was unreadable, or behaviour depends on data you cannot see.

## Open questions

Every `conflicting` or `unverifiable` rule should produce an open question that
a human owner can answer. Keep questions specific, answerable, and free of
speculation about intent.

## Rerun behaviour

- Compare against the committed data file, not against the previous rendered
  document, and run the deterministic ledger comparison described in the skill
  workflow (`-PreviousDataFile` on both the validator and the renderer).
- A changed classification is normal and expected; explain it in the note.
- Removing a rule from the implementation retires it; it does not remove it
  from the report.
