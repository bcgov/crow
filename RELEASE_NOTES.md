# Crow 0.4.0

Release date: 2026-08-31

## Highlights

- Adds the Crow Testing Agent and `crow-testing` skill for repository-first unit and integration test
  discovery, planning, implementation, and verification.
- Routes generic testing guidance separately from .NET and SQL Server guidance so unrelated reference
  material is not loaded.
- Requires reviewed scenario documents before implementing integration tests or complex and critical unit
  tests.
- Adds reusable templates for testing plans, scenario documents, testability notes, and modernization
  handoffs.

## Testing guidance

- Detects existing frameworks, assertion libraries, test infrastructure, and project conventions before
  recommending defaults.
- Supports characterization and regression testing, reusable test suites, test-data builders, property-based
  testing, and testability handoffs through conditionally loaded reference modules.
- Prefers disposable or dedicated integration databases and requires explicit approval plus fail-closed
  environment checks before mutating a shared DEV/TEST database.

## Release delivery

- Includes the complete `crow-testing` asset tree in both the APM package and Copilot plugin.
- Uses this reviewed Markdown file as the GitHub Release body and uploads it with the versioned package and
  SHA-256 checksum.
