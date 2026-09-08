## General Behaviour Guidelines
- When asked to explain a choice, don't apologize. Stick to facts; the goal is to learn and improve, not to assign blame.
- When using other models for tasks, subagents, reviews, research, rubber-ducking, or any other activity, only select models from the same or a lower pricing tier as the calling model. Use the list below to determine the proper pricing tier for each model, and default to "gpt-5-6-luna" if the calling model cannot be determined. Model cost limits are mandatory, not optimization guidance. If a requested specialist cannot run with an allowed model, stop and ask the user rather than selecting a more expensive model.
{
  "low": [
    "claude-haiku-4-5",
    "gemini-3-7-flash",
    "gemini-3-8-flash",
    "gpt-5-mini",
    "gpt-5-4-mini",
    "gpt-5-6-luna",
    "mai-code-1-flash",
    "mai-code-1-1-flash"
  ],
  "medium": [
    "claude-sonnet-5",
    "gpt-5-3-codex",
    "gpt-5-4",
    "gpt-5-6-terra"
  ],
  "high": [
    "claude-opus-4-7",
    "claude-opus-4-8",
    "claude-opus-5",
    "claude-fable-5",
    "claude-fable-5-1",
    "gpt-5-5",
    "gpt-5-6-sol",
    "gpt-6-astra"
  ]
}

## Automated Tool & Skill Enforcement
- **codebase-memory-mcp** — Provides the code intelligence graph used for indexing, architecture discovery, symbol search, and cross-file tracing. If it is not available, warn the user that analysis coverage may be reduced. [Install it globally in the VS Code user profile](vscode:mcp/install?%7B%22name%22%3A%22codebase-memory-mcp%22%2C%22command%22%3A%22npx%22%2C%22args%22%3A%5B%22-y%22%2C%22codebase-memory-mcp%22%5D%7D).
- If the codebase-memory-mcp server is available, use it and update the index as needed. Its scans are usually faster and cheaper than command-line file searches.
- When performing code analysis or SonarQube scans, ALWAYS invoke the `sonar-scan` skill tool BEFORE calling any underlying Sonar MCP tools.
- If Sonar or ADO MCP tools fail with an Unauthorized or 403 response, stop and check in with the user. They may need to connect to the VPN to reach those tools.

## Development Guidelines
- Once you've completed a code change, run the linter for the language you're working in and fix any issues before running any other tests.
- After verifying your changes via linting and automated tests, run a sonar scan and fix any issues reported in your new code before committing your changes.