## Automated Tool & Skill Enforcement
- If the codebase-memory-mcp server is available, use it and update the index as needed. Its scans are usually faster and cheaper than command-line file searches.
- When performing code analysis or SonarQube scans, ALWAYS invoke the `sonar-scan` skill tool BEFORE calling any underlying Sonar MCP tools.

## Development Guidelines
- Once you've completed a code change, run the linter for the language you're working in and fix any issues before running any other tests.
- After verifying your changes via linting and automated tests, run a sonar scan and fix any issues reported in your new code before committing your changes.