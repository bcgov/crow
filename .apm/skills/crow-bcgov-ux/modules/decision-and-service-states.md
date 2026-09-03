# Decision explanations and service states

Load this technology-neutral module only when a supplied screen or flow
displays an automated eligibility/denial decision, a result from an external
register or service, or a degraded, asynchronous, offline, or assisted state.
This module governs point-of-use communication, not journey or policy design.

For authentication, step-up, authorization, expiry, revocation, or dependency
failures, explain the user-visible state without exposing security-sensitive
rules. Distinguish denied, expired, revoked, unavailable, and pending results;
never imply that a degraded path has the same authority as the normal path.

## Point-of-use explanation and recourse

When the interface presents an automated or external decision:

- say what happened in plain language, identify the decision/result and its
  effective time or source freshness where useful;
- explain the relevant reason or factors at a level supported by the approved
  policy and available evidence, without exposing another person's data,
  security-sensitive rules, or claims the product cannot substantiate;
- distinguish a final decision from pending, unavailable, stale, or
  provisional information;
- provide an actionable recourse path at the point of use: correction of
  source information, review by an appropriate person, contact or alternate
  channel, and what information or next step is needed;
- preserve the existing business outcome and authorization. Do not invent
  eligibility policy, change a denial into an approval, or design an
  end-to-end journey as part of this UX work.

Where appropriate, expose decision provenance such as the source/service,
version, timestamp, or last successful refresh. Omit unavailable provenance
and label it unknown rather than guessing.

## Degraded, asynchronous, offline, and assisted states

Define the reachable state and the user's next action for:

| State | Required communication |
|---|---|
| Degraded or dependency unavailable | Explain the limitation, whether work is safe to continue, and the retry or assisted option. |
| Asynchronous or pending | State that no final result is available, describe how status can be checked, and avoid duplicate submission. |
| Offline or stale | Identify what is unavailable or stale, its timestamp where known, and do not present it as current. |
| Assisted/manual | Explain who or what will assist, what information is needed, and how the user can obtain follow-up. |

Use persistent text plus suitable programmatic status announcements. Keep
focus, keyboard access, error recovery, and screen-reader order usable. Do not
hide a consequential failure in a spinner or silently retry an action with
side effects.

## Review evidence

Record the screen/state sampled, observed wording and provenance, available
recourse, assistive-technology announcement, and the source or product rule
that constrains the behavior. Mark missing policy or unavailable service
behavior as a question or manual-verification item, not as a confirmed UX
fact.
