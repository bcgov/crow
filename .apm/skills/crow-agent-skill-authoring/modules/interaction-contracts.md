# Interaction Contracts

Use this module when an agent interviews users, writes documents, hands work
to another agent, reads a live provider, or can be resumed. It is the
canonical standard. In each agent, state only the applicable rule in two to
four lines and link here. Do not copy this module into agents.

## Evidence before writes

When an output depends on facts a user must confirm:

1. Inspect the available repository, document, and provider evidence first.
2. Draft the affected facts with a confidence label: `Verified` (direct
   evidence), `Inferred` (reasoned from evidence), or `Unknown`.
3. Ask only about material `Inferred` or `Unknown` facts. Group related
   questions and ask one group at a time.
4. Record the confirmation, then write.

Never raise a confidence label without new evidence or explicit user
confirmation. Do not ask the user for facts the evidence already establishes.

## Approval and write permission

Invoking an agent permits it to write its declared outputs. Require separate,
explicit approval before:

- writing outside the declared outputs, including tickets, external systems,
  `crow.config`, and client configuration;
- replacing or deleting human-authored content;
- marking a handoff `signed-off`, or giving a draft to an agent that generates
  or builds from it.

Approval for one action never implies approval for a later action.

## Completion report

End every run with a report that uses this shape. Omit empty lines except
`Status`, `Outputs`, and `Next step`.

```text
Status: complete | partial | blocked | failed
Scope: what was in scope, and anything explicitly excluded
Outputs: paths created or changed, or "none"
Evidence: sources inspected; label inferred or unavailable evidence
Findings and decisions: material results only
Open items: blocking, advisory, and deferred items
Checks: validation commands and results
Next step: one recommended action, and any offered handoff
```

- `complete`: every in-scope output exists and every check passed.
- `partial`: the user explicitly accepted a reduced scope; list what was not
  done.
- `blocked`: a required input, decision, tool, or approval is missing; name it.
- `failed`: an output or check failed; report the failure verbatim.

Never report a plan, scaffold, preview, or dry run as executed work. Never use
`complete` when a check was skipped without user acceptance.

## Open items

Classify every unresolved item:

| Class | Meaning | Record |
|---|---|---|
| Blocking | Prevents a correct output | question and affected outputs |
| Advisory | Output is usable, but a risk remains | owner, impact, and when it must be resolved |
| Deferred | The user chose to postpone it | fallback in use; never report it as verified |

A later contradiction reopens every dependent phase or output. Carry open
items forward until they are resolved; never drop them silently.

## Handoff contract

A handoff file passes confirmed work from a producer agent to a consumer
agent. It records:

- schema version, producer, consumer, generation time, and source revision;
- scope and requested work;
- status: `draft` or `signed-off`;
- artifact and evidence paths, relative to the repository;
- open blocking items, which must be empty when signed off;
- confidence (`Verified`, `Inferred`, `Unknown`) for each recorded fact.

The consumer validates that the listed files exist, the source revision is
current or the user accepts the difference, and the status is `signed-off`
before it generates or builds anything. The source revision is current when
the consumer's revision descends from it and no listed file has changed since;
the handoff file itself does not count. A draft may only be reviewed. Use a
deterministic validator when the format is JSON. Never run the consumer
automatically or imply that it accepted the handoff.

Agents may also declare VS Code `handoffs` frontmatter for the same
transition. Use the exact target agent `name`, a short `label`, a `prompt`
that names the handoff file or outputs to use, and `send: false` so the user
reviews the prompt first. Do not set `model`. Other harnesses ignore this
field, so keep the transition described in the agent body as well.

```yaml
handoffs:
  - label: Review agent changes
    agent: Crow Agent & Skill Review Agent
    prompt: Review the agent and skill changes in this branch.
    send: false
```

## Live-provider contract

When an agent reads a live provider (database, Sonar, ticketing, registry, or
cloud API), state:

- the tool and the authentication boundary; never request, log, or store
  credentials;
- the read-only operations allowed; any write needs the approval above;
- the fallback when the provider is unavailable, usually local evidence with
  reduced confidence;
- labels that distinguish live results from inferred or cached results;
- explicit confirmation naming the target environment before production
  access;
- row, sample, and timeout limits for queries.

## Resumable sessions

When prior outputs exist:

1. Read the prior outputs, decisions, and open items before asking anything.
2. Do not ask again about confirmed facts unless new evidence contradicts them.
3. Carry open items forward, and record where the work paused.
4. Move resolved items to a `Resolved` section with the resolution date
   instead of deleting them, unless the output contract defines another
   lifecycle.

## Preserve existing content

Before changing an existing human-authored document, compare it with the
proposed content. Update generated sections in place and keep human-authored
sections. When a section mixes both, offer the user the choice of a scripted
update, a manual edit, or both. Never replace the whole document silently.

## Supplied documents

Ask once whether the user has relevant documents, such as requirements,
designs, runbooks, or training material. Cross-check them against code and
configuration evidence, cite the source of each fact, and surface
contradictions instead of choosing silently. For business rules, use the
business-rule reconciliation workflow when it is installed.

## Re-checking assumptions

When a decision depends on facts that can change, such as an owner choice,
platform availability, or a vendor or support lifecycle, record
`last_confirmed` and `review_after` dates in the agent's own decision record.
Re-check expired entries on resume. Do not store these dates in `crow.config`.
