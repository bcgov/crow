# Reference provenance and release gate

The 28 files in `references/` were migrated from the user-provided
`CopilotDWTools` source project. This commit records the migration and routing
work; it does **not** assert that every source passage is independently
redistributable.

The corpus includes original project guidance plus summaries, patterns, and
links associated with Microsoft, Kimball Group, SQLBI, DAX Patterns, and other
named sources. Before publishing a release containing these files, the
maintainer must confirm one of the following for each file:

1. the source project owner authorizes redistribution under this repository's
   license;
2. the material is original or sufficiently transformed and its external
   sources are attributed; or
3. the file is replaced by an original summary with links to the source.

Until that review is complete, this corpus is a committed migration artifact
but a public-release blocker. Do not describe the package as release-ready
solely because Crow asset validation passes.
