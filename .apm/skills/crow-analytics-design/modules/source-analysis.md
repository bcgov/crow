# Local source analysis

Prefer repository SQL/DDL, migration definitions, schema files, mappings,
model files, CSV headers, sanitized samples, and existing documentation.
Record the inspected paths and the boundaries of what each source proves.
Use structural or aggregated evidence in design artifacts; do not copy raw
production rows, personal information, secrets, or extracts into repository
files, logs, or handoffs.

For each entity, capture available keys, relationships, date/status fields,
grain clues, and data-quality checks that can be established from the
available evidence. Do not claim runtime row counts, null rates, duplicate
rates, samples, or freshness from static definitions.

For CSVs, extracts, and manual notes, preserve the supplied evidence and
assumptions. Keep proposed relationships in a separate inferred section with
low confidence; do not merge them into confirmed relationships. Ask for
confirmation when a relationship or business meaning affects the grain or
bus matrix.

Live profiling requires an explicitly requested and reviewed provider
contract specifying the tool, authentication boundary, allowed operations,
failure behavior, freshness, confirmation gate, and scope limits. No provider
is implied by this skill. If the contract is unavailable, use local evidence
where sufficient and state what remains unverified; otherwise stop with a
blocking limitation.
