# Client-specific invocation

Read only the active client's section. Confirm that the installed skill or
agent appears in that client's discovery UI. Client/version differences
matter; if a recipe does not match the active harness, consult its official
documentation instead of inventing syntax or changing configuration.

APM's `--target` chooses where assets are installed. It is not a command for
selecting an agent during a conversation. The full package is
`bcgov/crow#stable`; the deprecated collection addresses are compatibility
wrappers, not different capability sets. Installation is a separate user
action, never something this skill executes.

## VS Code Copilot

Select **Crow Getting Started Agent** in the Agent dropdown. For the next
task, select the recommended specialist from the same dropdown and paste the
prompt. Do not present `@Agent Name` as a universal custom-agent selector.

For a coordinator, use the normal agent session with the coordinated prompt.
Ask it to use the available subagents/subchats only when the host supports
them and the prompt authorizes that coordination. Optional handoff buttons
are not required for this workflow.

Reference: [VS Code custom agents](https://code.visualstudio.com/docs/agent-customization/custom-agents).

## Copilot CLI

Use `/agent` to discover and select the installed agent, then submit the
prompt. Verify the displayed name rather than assuming a shell argument or
an `@` mention selects it. If the active version has no usable custom-agent
selection, explicitly request the relevant installed skill in the normal
session.

Start coordinated work in the normal session. Have it establish which worker
tools it actually has; do not promise that VS Code subchats exist in the CLI.
Use `/help` and the
[Copilot CLI documentation](https://docs.github.com/en/copilot/concepts/agents/about-copilot-cli)
to resolve version-specific discovery.

## Claude Code

Invoke `/crow-getting-started` after verifying it is listed. For the next
task, invoke the chosen skill with `/skill-name`, or ask Claude to use the
installed specialist shown by its agent discovery. An agent's Crow display
name need not be its client-transformed identifier.

For coordinated work, submit the orchestration prompt in the normal session,
naming verified installed specialists and skills. Confirm available subagent
support rather than assuming another client's tool names.

References: [Claude Code skills](https://code.claude.com/docs/en/skills) and
[subagents](https://code.claude.com/docs/en/sub-agents).

## Codex

Use `/skills` or type `$` to select `crow-getting-started`. A next-task prompt
can explicitly mention the selected skill, for example `$crow-testing`.
Do not assume a Crow custom agent has a native agent-picker equivalent.

For a coordinator, submit the coordinated prompt to the normal session with
explicit skill mentions. Verify whether the active Codex client supports
workers; otherwise use the manual fallback below.

Reference: [Codex skills](https://developers.openai.com/codex/skills).

## Cursor

Type `/` in Agent chat and select `crow-getting-started`. Use the same skill
picker for the next task, or a verified native specialist when available.
Do not substitute Copilot agent syntax.

Submit the coordinated prompt in Agent chat. Use native workers only if they
are available; skill support alone does not prove subagent support.

Reference: [Cursor skills](https://cursor.com/docs/skills).

## Other clients and missing capabilities

Ask which harness and invocation features are available. If a skill is
discoverable but there is no explicit picker, use a plain prompt naming the
skill and ask the host to confirm it loaded the installed guidance. Never
claim that ordinary keyword matching guarantees selection.

If workers are unavailable, preserve the same dependencies, owners, and
approval gates using sequential specialist sessions or one normal session
loading the relevant skills. Keep starting the coordinator as the recommended
action: its generated prompt instructs it to supply the first sequential
specialist assignment and identify the approved outputs to bring back.
Getting Started supplies a standalone specialist prompt instead only when
the user explicitly chooses not to start a coordinator. Do not claim the
manual fallback provides independent or parallel execution.

If Crow itself is unavailable, report that prerequisite and provide the
appropriate full-package installation guidance for user review; do not claim
the recommended agents can run yet.
