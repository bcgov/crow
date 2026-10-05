# Collection Management

Crow collections are optional APM packages under the repository-root
`collections/` directory. They are curated subsets of the full package; they
must not duplicate or fork the source assets under `.apm/`.

## Collection contract

- Keep one `apm.yml` and one human-facing `README.md` in each collection
  directory.
- Use explicit dependencies on `https://github.com/bcgov/crow.git` with paths
  such as `.apm/skills/<name>` or
  `.apm/agents/<name>.agent.md`, and set `ref: v<version>`. APM rejects
  `..` traversal in dependency paths, so a collection cannot point back to a
  local parent directory.
- Keep the collection version equal to the root `apm.yml` and
  `.github/plugin/plugin.json` versions. APM resolves the `#v<version>` ref
  against the repository, not against an individual subdirectory.
- Include every supporting skill explicitly when an agent loads it by name.
  A collection should work without the full Crow package being installed.
- The Crow asset validator builds an agent/skill dependency graph and checks
  that collection manifests include transitively linked skills and modules.
  Keep that check green when changing an agent, skill, module, or collection.
- Keep collection READMEs focused on purpose, included assets, prerequisites,
  and the release-tagged install command.

## Change workflow

1. Decide whether the capability belongs in an existing collection before
   creating a new collection.
2. Update the collection manifest and README together with the source asset.
3. Verify every dependency path resolves inside the repository and remains
   covered by the root package's explicit publication allowlist. Run the
   asset validator's dependency-graph check to verify agent-to-skill and
   skill-to-module closure.
4. Update the root README's collection links and the release-relevant workflow
   when collection distribution changes.
5. Run the Crow asset validator and test a local APM resolution or package
   check before release.

Collections are distribution overlays, not a replacement for the full Crow
package. Do not remove an asset from the root package solely to make a
collection smaller.
