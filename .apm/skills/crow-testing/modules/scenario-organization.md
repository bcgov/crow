# Deriving a repository's scenario organization

Load when feature-level scenarios are being planned or testing documentation is being organized and
`docs/testing/guides/scenario-organization.md` is absent. Do not run a repository-wide reorganization
for a simple unit test or replace an established layout without approval.

## Discover feature homes

1. Inspect existing testing docs, reviewer-supplied group names and code/tests first. Map
   applications or independently deployed services from manifests, entry points and deployment
   boundaries, not from a guessed product name.
2. Look for user-facing feature boundaries in vertical-slice folders, route/endpoint registration,
   controllers, navigation, pages/screens and their corresponding tests. Reconcile routes with actual
   application ownership; a shared library or similarly named folder alone is weak evidence of a feature.
3. Propose an application -> feature/page group -> feature map using the project's own terms. Cite a
   source path, route or existing document for inferred groups. Include groups explicitly approved
   by reviewers even when no feature or route exists yet; identify them as planned vocabulary, not
   implemented coverage. For any such group without a confirmed application owner, record the
   proposed owner for review and leave placement pending. If the application is known and no approved
   group is applicable, use `docs/testing/scenarios/<application>/<feature>/`. An approved group
   that might own the feature but has pending ownership takes precedence over this fallback. Use
   `docs/testing/scenarios/<feature>/` only when no application boundary applies; leave existing
   documents in place while an applicable application's or group's ownership is unresolved; do not
   create new scenario documents there until placement is confirmed. Do not copy groups from another
   project.
4. Assign one canonical home to cross-application behavior and link to it from each affected app's manual
   index row. Preserve purposeful multi-document feature sets, diagrams and scenario IDs.
5. Present inferred boundaries, approved vocabulary and first-use group ownership for developer/business
   reviewer confirmation. Do not write the guide or relocate scenarios on the strength of an unaccepted
   inference. An approved group with no feature may be listed in the guide with ownership pending;
   do not create its folder or place scenarios under it until its application owner and folder slug
   are confirmed. If ownership cannot be confirmed, keep the existing layout and record the decision
   as open; defer creation of new feature and manual documents needing that placement.

After approval, create `docs/testing/guides/scenario-organization.md` using the
[`scenario-organization-template.md`](../templates/scenario-organization-template.md) shape. Document only
approved groups, confirmed or pending application ownership, slugs and placement rules. Link it from
the testing README (typically `docs/testing/README.md`) when present. For a new testing documentation
set, create `docs/testing/README.md` as the landing page that indexes and links to feature homes, not
as a feature directory itself. Maintain the single `manual-coverage.md` browse/release index with links
to runnable checks under each owning feature.
For short single-document features, the group or page folder itself may be the feature home; add a
child feature folder only when it helps keep related documents together. Do not create empty folders,
duplicate expected results across indexes, or assume a smoke subset without an agreed selection.
When a pending owner is confirmed, update the guide and revisit placement; move existing documents
only with approval, preserving scenario IDs and updating the testing README (typically
`docs/testing/README.md`), plan and manual index together. Flag preexisting duplicate cross-application
checks as a consolidation candidate rather than silently moving or copying them.
