# Crow Versioning Policy

Crow uses semantic versioning for the combined APM and Copilot plugin package.

## Version selection

| Change | Version |
|---|---|
| Compatible correction, clarification, optimization, or fix to an existing capability | Patch |
| New agent, skill, module family, supported technology, output type, or other user-visible capability | Minor |
| Incompatible rename, removal, installation change, invocation contract change, or output contract break | Major, only when the user decides |

Use the highest classification present in the release diff. A new capability remains minor even when it also updates existing skills. Security fixes are patch unless they add a new user-visible capability or require an incompatible contract.

## Major release control

The agent must explain the incompatibility and ask the user whether to release a major version. Scripts require `-ConfirmMajor` as a second independent guard. Neither prior release history nor the apparent size of a change authorizes a major release.

## Release source of truth

The same version must appear in:

- `apm.yml`;
- `.github/plugin/plugin.json`;
- README installation commands, archive names, and packaging examples;
- the version heading in `RELEASE_NOTES.md`.

The release tag is `v<version>`. GitHub Releases is the publication record. The reviewed Markdown notes,
APM archive, and SHA-256 checksum are release assets.

## Release safety

- Prepare versions in reviewed source changes before publication.
- Publish from a clean, pushed default-branch commit.
- Create and push an annotated tag before creating the GitHub release.
- Require `gh release create --verify-tag` so publication cannot silently tag the wrong commit.
- Use the reviewed repository-root `RELEASE_NOTES.md` as the release body and upload it as an asset.
- Do not include research evidence, local caches, internal links, credentials, or untracked scratch files in assets.
- Keep `apm.yml` on an explicit publication allowlist; Git-ignored files under `.apm/` are otherwise eligible for packaging.
