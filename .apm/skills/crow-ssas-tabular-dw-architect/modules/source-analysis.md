# Source analysis

Mode P accepts three source-discovery paths:

1. **Path A — SQL Server**: local SQL/SSDT/TMDL definitions or reviewed
   provider evidence. Inventory entities, PK/FK candidates, dates, statuses,
   nulls/duplicates that are statically observable, and fact/dimension/bridge
   candidates.
2. **Path B — CSV**: CSV headers, samples, or exports from another system.
   Preserve the supplied evidence, treat FK relationships as inferred, and
   place them in a separate **Inferred Relationships (low confidence)**
   section.
3. **Path C — Manual**: user-supplied source notes when CSV evidence is not
   available. Preserve the stated evidence, mark database-only metadata as
   unavailable, and keep confidence low until the user confirms the map.

Return a Mode P entity map with proposed grain and confidence. Live profiling
is deferred without a reviewed provider contract; no fabricated row counts or
samples. For Path B and Path C, do not merge inferred relationships into the
confirmed-relationship section.
