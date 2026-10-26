# Guided Onboarding

Load when the user is new to Raven, asks "what is Raven", has no recorded
setup state, or a first attempt failed. Skip for a user who names exact
server IDs and wants a fast install.

## Interview (at most 3 questions, one per turn)

Offer structured choices with the recommended option first. Skip any question
whose answer is already known from `status` or the request. Record the answers
as the setup intent and have the user confirm it before planning.

1. **Path.** `A [Recommended]` Learn first, then set up · `B` Set up by my
   role · `C` Fast-track: I know the server IDs.
2. **Client and OS.** Detect both (`status`, `uname`). Confirm only if
   ambiguous. Clients are listed in [`client-targets.md`](client-targets.md).
3. **Role** (path B only). Developer, QA, project manager or product owner,
   security, operations, data or analyst. Map the role to a starter server
   set with `starterSets` in `resources/raven-servers.json`. Present it as
   a proposal; the user edits it.

## Path A: learn first

Load [`learn-raven.md`](learn-raven.md). Teach in short steps and pause for
questions between them. Do not start installing until the user says to continue.

## Path B: role-guided

Propose the starter set, explain in one line why each server is included, then
continue with the normal workflow in `SKILL.md`.

## Teaching rules

- Explain each step before running it: what it does, what it changes, how to
  undo it.
- Introduce one credential group at a time. A user who only needs Jira and
  Confluence should not be asked for Jenkins or SharePoint values.
- Never ask the user to paste a secret into chat. Send them to the credential
  flow in [`credentials.md`](credentials.md).
- Separate three states in every report: **installed**, **configured**
  (client config applied), **authenticated and verified**. Setup is not
  complete until the third state is reached or the user defers it.
