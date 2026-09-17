# SSAS Tabular adapter

Inspect local `.bim` or TMDL files. Document tables, columns, and measures
using the model's native `description` property where supported. Record
relationships, partitions, and non-trivial filter context using the format's
supported relationship metadata or a separate documentation note; do not
pretend every relationship has a native description field. Preserve D3 naming
and coverage, but do not assume a live DMV connection. Skip private/system
objects and hidden or underscore-prefixed technical objects unless the user
explicitly includes them. Record skipped objects and never overwrite existing
metadata without confirmation.
