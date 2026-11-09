# Sysdig Skills Offer

## Trigger and boundary

Use this module only when the user selects `sysdig-secure-mcp` during the
current setup, or asks to install or update Sysdig's skills. Crow does not
vendor, copy, or modify these skills. They are published and maintained by
Sysdig at `github.com/sysdig/skills`; the agent offers to install them directly
from that repository, following the repository's "Compatibility with other
agents" instructions. Keep this offer, its preview, and its approval separate
from the MCP client-config merge, the Raven setup plan, and Sonar scanner
setup. Declining the skills never blocks the MCP configuration.

Tell the user that these skills are third-party content that Crow has not
reviewed. They are instructions plus Python scripts that run in the user's
agent.

## Resolve the version

Resolve the latest tag from the official repository at invocation time, for
example `gh api repos/sysdig/skills/tags --jq '.[0].name'`, and use that exact
tag. Never hardcode a tag, install from `main`, or reuse a tag from an old
prompt. If the tag cannot be resolved, report the failure and defer the offer.

## Skill groups

Offer one default set: every Sysdig skill except the API-token skills. The user
may remove skills from it, but the offer starts from the full set. Skills hand
work off to each other, so a partial set reaches dead ends when a skill tries
to hand off to one that is not installed.

| Workflow | Skills | Notes |
|---|---|---|
| Vulnerabilities, from finding to fix | `sysdig-investigate`, `sysdig-remediate`, `sysdig-sysql` | `sysdig-investigate` finds and prioritizes vulnerable images and hands the chosen image to `sysdig-remediate`, which proposes the upgrade, opens the pull request and files or updates the ticket. `sysdig-sysql` helps write and run SysQL queries against the security data. |
| Runtime threats, from detection to containment | `sysdig-runtime-investigate`, `sysdig-runtime-remediate` | `sysdig-runtime-investigate` investigates a detected threat, hands off to `sysdig-runtime-remediate` for containment actions, and links the threat to known vulnerabilities through the vulnerability skills above. |
| Account setup | `sysdig-account-setup` | Teams, roles, policies and detection settings for a newly connected tenant. |
| API token (excluded by default) | `sysdig-onboarding`, `sysdig-posture` | Mention that they exist. They call Sysdig's REST API or Terraform provider with a long-lived API token instead of OAuth. Offer them only if the user asks. |

State before the user confirms that `sysdig-remediate`, `sysdig-runtime-remediate`
and `sysdig-account-setup` can change things (pull requests, tickets, job state,
containment actions, tenant configuration). If the user removes a skill whose
partner stays (for example `sysdig-remediate` while keeping `sysdig-investigate`),
name the partner and the hand-off that will no longer work, and let the user
decide.

If the user asks for the API-token skills, explain that the token is created in
Sysdig (Settings, Sysdig Secure API) and exported by the user as
`SYSDIG_SECURE_API_TOKEN` and `SYSDIG_SECURE_URL`; the token works outside the
user's OAuth sign-in. Never ask for, display, or store the token, and never
tell the user to paste it into chat.

Verify the skill names against the repository at the resolved tag
(`npx skills add sysdig/skills#<tag> --list`) before offering them; skip any
name that no longer exists and say so.

## Preview and install

Before installing, show a plan containing:

- the exact tag, the chosen skill names, and the exact command;
- that the install clones `github.com/sysdig/skills` over HTTPS at that tag, and
  that the `skills` CLI does not verify a content hash;
- that the `skills` CLI reports anonymous install telemetry;
- the Python 3 requirement of the skill scripts (standard library only), with
  the detected status;
- the install location and the exact removal command.

Require explicit confirmation. Then run, once per confirmed selection (the
active client is Copilot, so use `github-copilot`):

```text
npx skills add sysdig/skills#<tag> --skill <name> [--skill <name> ...] --agent github-copilot --global --copy --yes
```

Use `npx.cmd` on Windows PowerShell when script execution is disabled. The
`skills` CLI command is `add`; Sysdig's README shows `npx skills install`, which
the CLI does not provide. For a client other than Copilot, use the agent
identifier documented by the `skills` CLI for that client, or give the user the
command without running it.

## Verify, update, and remove

Verify with `npx skills list --global` that each selected skill is present, and
report the installed tag. Do not run any Sysdig skill or call a Sysdig tool as a
setup check. Remind the user to sign in to the `sysdig-secure-mcp` server in the
client (OAuth) before using the skills, and to restart the client or start a
new session if the skills are not listed.

On later setup or maintenance requests, compare the latest tag with the tag
reported at install (from the handoff record or `npx skills list --global` when
it shows one); if the installed tag is unknown, say so and offer a reinstall at
the latest tag. A pinned install does not update itself, so reinstall only
after confirmation. Remove skills with
`npx skills remove <name> --global` after confirmation. Do not keep Sysdig skill
state in Crow setup state.
