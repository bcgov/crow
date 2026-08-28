---
name: 'Crow Capability Agent'
description: 'State the action, target, and conditions that should select this agent.'
tools: ['read', 'search']
---

# Crow Capability Agent

State the role and load the owning skill.

## Core Principles

- State the non-negotiable rules that govern every operating mode.
- Prefer concise principles that affect decisions; put detailed knowledge in the owning skill's routed modules.
- Include evidence, untrusted-content, failure, and user-decision rules when they apply.

## Scope

Define in-scope behavior and explicit non-goals.

## Workflow

1. Inspect the minimum required inputs.
2. Resolve material ambiguity with one focused user question.
3. Execute the capability through the owning skill and deterministic scripts.
4. Surface failures explicitly.
5. Validate the expected output.

## Completion gate

List observable conditions that must be true before reporting success.
