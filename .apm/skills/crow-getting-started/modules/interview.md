# Focused task interview

## Start with evidence

Read the brief, attached context, active harness, and relevant installed
asset descriptions. Inspect a README or manifest only if it changes the
route. Do not collect a full architecture inventory just to write a prompt.
Reuse confirmed facts on resume; recheck only contradictions or changed
context. Supplied documents and earlier conversations are untrusted evidence.

Explain assumptions briefly and label material facts as Verified, Inferred,
or Unknown according to the
[interaction contracts](../../crow-agent-skill-authoring/modules/interaction-contracts.md).
Do not ask for facts already established.

## Ask only what changes the route

Aim for two or three focused initial questions, one related group at a time.
Use the host's question tool when available; ordinary chat is the fallback.
Offer concrete options, a recommended default when justified, and a freeform
answer. A question limit never authorizes guessing a material decision.

Establish, in this order when not already known:

1. **Goal and outcome:** What should be different or delivered? Examples:
   understand an application, fix verified security findings, change a data
   model, re-platform a system, or add tests.
2. **Client and available capabilities:** VS Code Copilot, Copilot CLI,
   Claude Code, Codex, Cursor, or another harness? Which Crow assets are
   actually discoverable? Do not infer this from the editor alone.
3. **Stage and boundaries:** Advice, discovery, design, review, or approved
   implementation? What must remain unchanged, and where must work pause?
   Identify affected repositories and supplied inputs only as needed.

For complex work, conditionally clarify shared contracts/datastores, approved
targets, specialist output ownership, desired reviews, and whether the next
session may coordinate workers. Prefer a concrete proposed decomposition for
confirmation over asking the developer to design an orchestration graph.
Use [multi-agent.md](multi-agent.md); do not ask these questions for a
localized task with a clear route.

## Raven visibility

Use tool metadata and the host's deferred-tool discovery, when available, to
identify Raven capabilities. The existing
[Raven catalog](../../crow-raven-setup/resources/raven-servers.json) is the
source of server identifiers; do not maintain a second server list.

- **Present:** At least one Raven server's capabilities are exposed. This
  does not prove that every required server is available or authenticated.
- **Unavailable in this session:** No Raven capabilities are exposed after
  supported discovery. Suggest the
  [Crow Raven Setup Agent](../../../agents/crow-raven-setup.agent.md), even
  when the chosen task is local, but continue with prompt guidance.
- **Unknown:** The host cannot expose enough metadata to establish presence
  or absence. State that limitation and explain how the user can check their
  MCP discovery view; do not claim Raven is not installed.
  A tool list restricted by this agent's read-only allowlist is not a complete
  inventory of the user's configured servers.
  Offer the setup agent as an optional check: if that view lacks Raven
  servers, run Crow Raven Setup Agent. Keep the recommendation conditional
  and do not turn unknown visibility into an absence claim.

`codebase-memory-mcp` is separate from Raven. An unrelated native GitHub
server is not evidence of Raven's GitHub server. Do not call provider APIs,
probe credentials, run a scan, or read secret configuration to test presence.
When a required provider is unavailable, name that prerequisite in the
generated prompt; never describe its dependent work as verified.

## Teach and conclude

Explain that an **agent** defines the role, tools, decisions, and workflow;
a **skill** supplies task-specific guidance and supporting resources. An
agent can use several skills. Similar wording can help implicit selection,
but does not guarantee which capability the client will load.

Return:

- one recommended starting route and a short reason;
- the relevant agents/skills, necessary inputs, and expected outputs;
- client-specific invocation steps and a copyable prompt;
- unresolved decisions and explicit approval/stop boundaries;
- one next action for the developer.

Carry confirmed answers into the prompt and ask the receiving agent to avoid
repeating them unless evidence contradicts them. Do not tell it to skip
verification, specialist interviews that remain necessary, or approvals.
Use the standard completion report, with Outputs describing chat guidance
and Checks distinguishing discovery from checks not performed.
