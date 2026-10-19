# Azure DevOps pull request route

Resolve the organization, project, repository, PR ID, status, source/target
commits, iterations, and comment threads using an authenticated read-only
provider tool or Azure DevOps Git REST GET. Do not substitute `gh` or expose
provider credentials in commands or reports.

Enumerate the latest iteration's changes against the common commit
(`$compareTo=0`) using returned `nextSkip` and `nextTop` until both are zero.
For re-review also compare the earlier reviewed iteration and check relevant
thread status before claiming a concern was resolved. Read file contents at
pinned commits and compare the effective revisions; report inaccessible
history or files as coverage gaps. Quote URL parameters containing `$`, `?`,
or `&` when using a shell.

Recheck the source revision before reporting. Cite a provider permalink only
when the commit and line anchor are verified; otherwise provide revision,
path, and line in plain text rather than inventing a URL.
