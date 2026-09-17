# Local source profiling

Prefer repository `.sql`, `.sqlproj`, schema folders, `.bim`, and TMDL. Inventory entities, keys, relationships, date/status candidates, null/duplicate checks that can be established statically, and proposed grain. Label live row counts, samples, and runtime statistics unavailable when no reviewed provider is present.

Mode P is a handoff contract, not an invented API:
`{source, evidence, entities, candidate_grains, unknowns, requested_confirmation,
producer_version, consumer_version, requested_mode}`. A live SQL/SSAS provider
may be used only after the user explicitly requests it and a reviewed tool
contract exists. Never fabricate results.
