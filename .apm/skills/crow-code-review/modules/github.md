# GitHub pull request route

Resolve the owner, repository, PR number, head SHA, actual head repository
(including forks), and effective comparison. Use read-only `gh pr view/diff`
and paginated GET `gh api` calls to read reviews, review comments, issue
comments, and `repos/<owner>/<repo>/pulls/<number>/files?per_page=100`.
Cross-check the paginated file list against `changedFiles`; the files API
stops at 3,000 files. A missing patch or oversized diff is a coverage gap
until verified from source at the pinned revisions. REST comments alone do
not establish whether a review thread was marked resolved.

For a re-review, inspect the prior reviews and commits after the last
approval, identify which head revision the approval covered, and focus the
analysis on new changes plus unresolved earlier concerns. Do not treat a
new commit as automatically dismissing an older finding.

Recheck the head SHA before reporting. Cite head-side lines with a verified
link using the full SHA and actual head repository; include surrounding
line context where it exists. Cite base-only lines at their appropriate
base revision. Use a PR diff link for binary or non-renderable changes.
Do not guess line anchors or cite a changed head line with an outdated or
abbreviated SHA.
