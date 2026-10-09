# Scenario organization

<!--
Create only after reviewers approve the proposed vocabulary and evidence-based boundaries.
Use this project's names and evidence; do not import another project's category vocabulary.
Keep this a short routing guide, not a copy of the scenario inventory or business rules.
-->

## Applications and feature groups

| Application / service | Group or page | Folder slug | Evidence / owner decision |
|---|---|---|---|
| [Confirmed application, or Owner pending] | [Approved group/page, or feature directly if no grouping] | [Approved slug, or Pending] | [Route, page, vertical-slice path, or reviewer-approved future category; note proposed owner when pending] |

Include reviewer-approved groups even if they have no implemented feature yet. Mark uncertain
application ownership or slug as pending; confirm both before placing scenarios or creating folders.
An approved group that may own a feature but has pending ownership takes precedence over the
no-group fallback. Explain when an application name is itself the umbrella group; do not create a
redundant nested directory.

## Feature homes

- Follow existing document locations unless a move is approved. Otherwise place scenarios and supporting
  rules, diagrams and harness notes under `docs/testing/scenarios/<application>/<group>/<feature>/`
  when those boundaries are confirmed. Use `docs/testing/scenarios/<application>/<feature>/` when only
  the application is confirmed, or `docs/testing/scenarios/<feature>/` when no application boundary
  applies. Keep existing documents in place and defer new ones while applicable group or application
  ownership is unresolved.
- A short single-document feature may live directly in its confirmed group/page folder. Add a child
  feature folder when separate scenarios, rules, diagrams or manual checks benefit from being grouped.
- Give cross-application behavior one owning feature home. Link app-specific manual checks from their
  application/group rows in `docs/testing/manual-coverage.md`; do not copy scenario definitions.
- Keep runnable manual steps under the owning feature's `manual/` folder. Use
  `docs/testing/manual-coverage.md` as the single manual browse/release index. Use the testing README
  (typically `docs/testing/README.md`) as the landing-page index for feature homes, not as a feature
  directory itself. Update links and indexes when a feature or check moves.
- Keep stable scenario IDs; link automated coverage to test files or folders, not method names. Distinguish
  automated business-rule checks from rendered UI checks still requiring manual QA.
- When pending ownership is resolved, update this guide. Relocate existing documents only with approval
  and update links in the testing README (typically `docs/testing/README.md`), testing plan and manual
  index together.
- List approved future groups without creating empty folders or an unapproved smoke suite. Record QA
  execution outside the repository.
