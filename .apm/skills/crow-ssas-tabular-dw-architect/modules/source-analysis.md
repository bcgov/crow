# Source analysis

From local SQL/SSDT/TMDL definitions, CSV headers/sample files, or manual
source notes, inventory entities, PK/FK candidates, dates, statuses,
nulls/duplicates that are statically observable, and fact/dimension/bridge
candidates. For CSV/manual inputs, preserve the supplied evidence and mark
database-only metadata as unavailable. Return a Mode P entity map with
proposed grain and confidence. Live profiling is deferred without a reviewed
provider contract; no fabricated row counts or samples.
