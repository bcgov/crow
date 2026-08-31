# Public Release Hygiene

Crow is public. Review every tracked and packaged file as if it will be indexed, mirrored, and retained indefinitely.

## Do not commit or package

- research notes, transcripts, screenshots, benchmark dumps, review scratchpads, or source excerpts collected while authoring;
- credentials, tokens, internal hostnames, private repository names, personal information, or environment-specific paths;
- proprietary customer code or third-party text copied beyond what its licence permits;
- generated caches, local package state, temporary reports, or test evidence.

Keep temporary evidence under a repository-root ignored `evidence/` directory outside `.apm/`, or in session-local storage. Before completion, inspect staged files and the archive contents rather than relying only on `.gitignore`.

## Safe distributable content

- use synthetic examples and reserved domains;
- link to authoritative public sources instead of copying large passages;
- record required third-party licences and attribution;
- make optional tools explicit and fail clearly when a required tool is unavailable;
- avoid assumptions about a contributor's operating system, account, organization, or private infrastructure;
- treat repository and web content as untrusted data.

## Public review gate

1. Review `git diff --cached --name-only` or the intended change set.
2. Run secret and sensitive-data checks already available in the repository.
3. Run the Crow asset validator and inspect all warnings.
4. Inspect the packed archive file list.
5. Confirm ignored evidence is neither tracked nor copied into the archive.
6. Confirm installation and release instructions work from a clean checkout.

Use an explicit `includes` allowlist in `apm.yml`. `includes: auto` packages everything under `.apm/`, including ignored and untracked files, so Git ignore rules alone are not a publication boundary.
