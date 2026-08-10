## General Behaviour Guidelines
- When asked to explain a choice, don't apologize. Stick to facts; the goal is to learn and improve, not to assign blame.

## Automated Tool & Skill Enforcement
- **codebase-memory-mcp** — Provides the code intelligence graph used for indexing, architecture discovery, symbol search, and cross-file tracing. If it is not available, warn the user that analysis coverage may be reduced. [Install it globally in the VS Code user profile](vscode:mcp/install?%7B%22name%22%3A%22codebase-memory-mcp%22%2C%22command%22%3A%22npx%22%2C%22args%22%3A%5B%22-y%22%2C%22codebase-memory-mcp%22%5D%7D).
- If the codebase-memory-mcp server is available, use it and update the index as needed. Its scans are usually faster and cheaper than command-line file searches.
- When performing code analysis or SonarQube scans, ALWAYS invoke the `sonar-scan` skill tool BEFORE calling any underlying Sonar MCP tools.

## Development Guidelines
- Once you've completed a code change, run the linter for the language you're working in and fix any issues before running any other tests.
- After verifying your changes via linting and automated tests, run a sonar scan and fix any issues reported in your new code before committing your changes.