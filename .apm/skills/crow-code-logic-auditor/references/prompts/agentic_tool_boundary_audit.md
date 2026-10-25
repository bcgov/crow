# Inspection Prompt: Agentic Tool Boundary & MCP Execution Audit

Execute this inspection to evaluate Model Context Protocol (MCP) server endpoints, autonomous agent tool dispatchers, tool-call authorization boundaries, and secondary prompt injection propagation.

## 1. Tool Dispatch & Invocation Lifecycle
- Trace how agent tool calls enter the runtime (e.g. JSON-RPC over `stdio`, `sse`, or HTTP POST).
- Verify whether the executing identity is authenticated per tool call or if the tool relies on ambient daemon/process permissions.
- Check whether destructive tool parameters (file paths, SQL filters, entity/ticket IDs, shell commands) are strictly validated against an immutable allowlist or if raw LLM generation is passed directly to system APIs.
- Trace downstream propagation: when Tool A returns data (e.g., ticket comments, git commit logs), is it returned to the agent context as untrusted data or does it bypass policy boundaries in Tool B?

## 2. Invariant Checklist
- [ ] **Caller Authorization Bound**: Does every MCP tool handler independently enforce caller identity and RBAC/ABAC permissions before executing side-effects, rather than assuming upstream agent authorization?
- [ ] **Ambient Identity Rejection**: Does the tool runner execute actions with the caller's delegated permissions, rather than running as a high-privileged service account with unrestricted system access?
- [ ] **Dual-Execution Atomicity**: When an agent executes a multi-step sequence (e.g., `create_branch` -> `commit_code` -> `open_pr`), does a failure in step 3 roll back steps 1 and 2, or does the repository retain partial state?
- [ ] **Tool Result Taint & Injection Boundary**: Are tool output strings parsed and sanitized before being fed into downstream execution contexts to prevent indirect prompt injection from weaponized ticket content or repo files?
- [ ] **Human-in-the-Loop (HITL) Gate Integrity**: If a tool requires explicit human approval (destructive file write, production deploy, external network egress), can the agent bypass the gate via parameter aliasing or alternative tool routing?

## 3. Discriminating Test Vector
```python
def test_unauthorized_mcp_tool_execution_blocked():
    # Caller token belongs to unprivileged Viewer role
    viewer_client = get_mcp_client(role="viewer")
    
    # Attempt destructive tool call
    result = viewer_client.call_tool(
        name="execute_database_migration",
        arguments={"schema_version": "v2.0", "force": True}
    )
    
    assert result.is_error, "Invariant breached: Unprivileged caller executed destructive tool"
    assert "PERMISSION_DENIED" in result.error_code
```
