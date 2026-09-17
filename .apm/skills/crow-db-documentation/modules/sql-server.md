# SQL Server adapter (Phase 1)

For local source or DW SQL, inspect DDL, extended-property scripts, views,
procedures, functions, triggers, keys, and relationships. Preserve the
extended-property intent from `modules/extended-properties.md`: source
objects use `MS_Description`; DW objects may also require the full documented
property set and classification safeguards.

Generate safe, reviewable `sp_addextendedproperty`/update scripts only when
requested. Do not connect, query, or apply to a live server in Phase 1.
Record that live counts/statistics and absent metadata could not be verified.
Skip system and metadata objects such as `sys.*`, `INFORMATION_SCHEMA.*`,
temporary tables, replication/diagram metadata, and `RowVersion`/`timestamp`
columns unless the user explicitly includes them.
The future adapter contract is: enumerate context and objects, return evidence
and coverage, accept confirmed documentation changes, and report capabilities
and limitations. It must not be assumed that every provider supports SQL
extended properties.
