# CROW (Continuous Remediation & Optimization Workflows)

CROW is a collection of agents and skills for agentic software development. The intention is to set up this repo so that the agents and skills are available globally in VS Code or your favourite tool, so that they're available in any project you work on.

This repo is supposed to be used together with the RAVEN MCP server collection: [RAVEN](https://github.com/bcgov/raven)

## Available Agents

- **Architecture Review Agent**: Inspects a repository, analyzes its tech stack, and generates a verified `architecture.md` document in `/docs`.
- **Security & Dependency Review Agent**: Inspects repository frameworks, dependencies, known CVEs, security controls, and executes SonarQube scans to generate or update a `security-review.md` document in `/docs`.
- **Security Remediation Agent**: Remediates critical, high, and medium security vulnerabilities, framework/dependency technical debt, and test coverage gaps from `security-review.md`, then verifies and re-runs the security review.
- **Executive Summary Report Agent**: Synthesizes `/docs/architecture.md` and `/docs/security-review.md` into a high-level executive report highlighting critical security issues and technical debt in plain language, generating both Markdown and PDF output.

## Available Skills

- **sonar-scan**: Triggers when a code analysis, quality scan, or SonarQube / SonarCloud scan is requested using the `sonar-mcp` server.

# Use in VS Code

## On Windows

Check out the Git repo into the `%USERPROFILE%\.copilot` folder to make the agents and skills available globally in VS Code.

## On MacOS

Check out the Git repo into the `~/.copilot` folder to make the agents and skills available globally in VS Code.