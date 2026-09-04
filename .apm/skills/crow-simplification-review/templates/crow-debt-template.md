# Crow debt ledger

This ledger records deliberate, bounded technical debt in the repository. It
is intentionally broader than simplification: entries may cover legacy
libraries, end-of-life technology, modernization work, or other accepted
trade-offs.

## Marker format

Add a language-appropriate comment when a known ceiling and revisit condition
exist:

```text
# crow-debt: shortcut; <what was simplified>; ceiling: <known limit>; revisit: <measurable trigger>; owner: <team>
```

Use `type: legacy-library`, `type: modernization`, or another specific type
for non-simplification debt. Keep the marker near the affected code. Do not
put secrets, private URLs, customer data, or copied evidence in a marker.

## Ledger

Run the read-only `Get-CrowDebt.ps1` report from the
`crow-simplification-review` skill to harvest current markers. Entries below
are maintained only when a user explicitly asks to update this file.

| Location | Type | Debt / simplification | Ceiling | Revisit trigger | Owner | Status |
|---|---|---|---|---|---|---|
| — | — | No recorded Crow debt. | — | — | — | — |

## General debt comments

The report also includes a separate, read-only section for conventional
comments that may indicate follow-up work, including `TODO:`, `To-Do:`,
`Future:`, `Change:`, `FIXME:`, `HACK:`, `XXX:`, and `NOTE:`. These comments
are observations rather than Crow debt markers and are not copied into the
ledger automatically.
