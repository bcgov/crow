# SSAS Tabular adapter

Inspect local `.bim` or TMDL files. Document tables, columns, measures,
relationships, partitions, and non-trivial filter context using the model's
native `description` property. Preserve D3 naming and coverage, but do not
assume a live DMV connection. Skip private/system objects and hidden or
underscore-prefixed technical objects unless the user explicitly includes
them. Record skipped objects and never overwrite an existing description
without confirmation.
