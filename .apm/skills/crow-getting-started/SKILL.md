---
name: crow-getting-started
description: Help a developer learn Crow, choose agents and skills, and write a tool-specific prompt for their task. Includes advanced multi-agent orchestration prompts for cross-domain work. Guidance only, not task execution or automatic delegation.
---

# Getting Started with Crow

Use with the Crow Getting Started Agent, or directly in a client that
supports skills but not custom agent selection.

## Context-efficient routing

1. Read [interview.md](modules/interview.md). Use the brief, active client,
   and supplied context; do not begin with a full codebase scan.
2. Read the relevant rows of [task-routing.md](modules/task-routing.md).
   Verify candidate names and boundaries from their installed descriptions;
   load their full guidance only when needed to resolve a routing question.
3. Read only the active client's section of
   [client-invocation.md](modules/client-invocation.md). Confirm actual
   discovery rather than assuming installation implies availability.
4. For a single starting route, use the
   [prompt template](resources/prompt-template.md).
5. When the user requests orchestration, or several specialist outputs must
   be coordinated, read [multi-agent.md](modules/multi-agent.md) and use the
   [orchestration prompt template](resources/orchestration-prompt-template.md).
   Do not load it merely because many files are involved.

## Boundaries

This skill interviews, explains, and drafts prompts in chat. It does not
implement, scan, install, write plans or handoff files, launch workers, or
own another skill's workflow. Client recipes describe how the user starts
the next session; they are not permission to start it automatically.

Keep one recommended starting action. For complex work, that action can be
starting a coordinator with several specialist assignments, rather than
selecting a single specialist to perform the entire task.
