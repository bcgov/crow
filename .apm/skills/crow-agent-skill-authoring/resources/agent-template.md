---
name: '<Confirmed Agent Name>'
description: 'State the action, target, and conditions that should select this agent.'
tools: ['read', 'search']
# Optional. Add only when a follow-on agent naturally consumes this output.
handoffs:
  - label: '<Short action label>'
    agent: '<Exact target agent name>'
    prompt: 'Name the output or handoff file the target agent should use.'
    send: false
---

# <Confirmed Agent Name>

State the role and load the owning skill.

## Core Principles

- State the non-negotiable rules that govern every operating mode.
- Prefer concise principles that affect decisions; put detailed knowledge in the owning skill's routed modules.
- Include evidence, untrusted-content, failure, and user-decision rules when they apply.
- When the agent interviews users, writes documents, hands off work, reads a live provider, or resumes prior work, state the applicable [interaction contract](../modules/interaction-contracts.md) rule in one line each.

## Scope

Define in-scope behavior and explicit non-goals.

## Workflow

1. Inspect the minimum required inputs, including prior outputs when resuming.
2. Draft facts with confidence labels, then resolve material ambiguity with one focused group of user questions at a time.
3. Execute the capability through the owning skill and deterministic scripts.
4. Surface failures explicitly.
5. Validate the expected output.

## Completion gate

List observable conditions that must be true before reporting success.
End with the standard completion report and its `complete`, `partial`,
`blocked`, or `failed` status.
