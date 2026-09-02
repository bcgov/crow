# Managed copied-template lifecycle

Load this only when installing a ready-to-copy Crow template or when the managed-template audit reports
drift. It keeps copied utilities current without adding Crow provenance comments to project source files.

## Why two hashes are required

`docs/testing/testing-plan.md` records two independent install-time fingerprints and a management mode:

- **Source SHA-256** — Crow's untouched bundled template.
- **Installed SHA-256** — the project file after required adaptation, currently the target namespace.
- **Mode** — `Auto` for an unmodified managed copy; `Manual` after the user merges or retains project
  customizations. Manual copies are never overwritten automatically.

Hashes normalize BOM and line endings before comparison. A checkout, formatter, or editor changing CRLF to
LF is not a project customization. A later automatic replacement writes the bundled template as UTF-8
without a BOM, even when a registered file previously used a BOM.

For example, Crow's `GenCharExtensions.cs` uses `YourProject.Tests.Generators`. Installation changes that to
the project's namespace and hashes the resulting file. A later source-hash change means Crow updated the
template. The installed hash then answers whether the project changed its adapted copy afterward.

## Use the deterministic script

Resolve `scripts/Sync-CrowTestingTemplate.ps1` from the loaded crow-testing skill root, then invoke that
bundled script as a separate PowerShell process (`powershell` on Windows PowerShell or `pwsh` on PowerShell
Core) rather than copying or editing registry hashes by hand. If an existing `testing-plan.md` predates the
registry section, add the **Managed Crow templates** section from `templates/testing-plan-template.md`
before the first install. Never regenerate the testing plan wholesale; preserve its registry.

```powershell
$syncScript = '<crow-testing skill root>\scripts\Sync-CrowTestingTemplate.ps1'

# Install a new managed copy and register both fingerprints.
powershell -NoProfile -File $syncScript -Action Install `
  -TargetRepo C:\Projects\Example `
  -TemplateId example-tests-gen-char `
  -Source dotnet/generators/GenCharExtensions.cs `
  -TargetPath tests\Example.Tests\Generators\GenCharExtensions.cs `
  -Namespace Example.Tests.Generators

# Audit every registered template.
powershell -NoProfile -File $syncScript -Action Audit -TargetRepo C:\Projects\Example

# Apply safe updates. Exit code 3 means user action is required.
powershell -NoProfile -File $syncScript -Action Update -TargetRepo C:\Projects\Example

# After reviewing a customized copy, record the explicit decision.
powershell -NoProfile -File $syncScript -Action Resolve `
  -TargetRepo C:\Projects\Example `
  -TemplateId example-tests-gen-char `
  -Resolution Merge
```

Use `-Action Register` only for an existing file that exactly matches the current template after namespace
and line-ending normalization. If it differs, reconcile it first; treating an unknown customized file as an
unchanged baseline would make a later automatic overwrite unsafe. Use a unique template ID per installed
copy, so separate test projects in a monorepo can install the same source template independently.

If PowerShell is unavailable, an unmanaged manual copy is still allowed: copy the required template, change
its namespace, and do not add a registry row. State in `testing-plan.md` that the file is unmanaged; Crow
cannot detect or apply later template updates automatically.

## Interpret audit/update results

| Status | Meaning | Action |
|---|---|---|
| `Current` | Neither Crow nor the project changed the managed file | None |
| `SafeUpdateAvailable` | Crow changed; project copy still matches its installed fingerprint | Run `Update`; replacement is safe |
| `Updated` | Latest template was adapted and installed automatically | Review and run the affected tests |
| `Customized` | Project changed its copy; Crow source is unchanged | Preserve it; update the registry only after an explicit decision |
| `CustomizedWithUpstreamChange` | Both changed | Never overwrite; compare the emitted candidate with the project file and ask merge/replace/retain |
| `ManualCurrent` | A previously merged/retained copy has no new drift | None; it remains protected from automatic replacement |
| `ManualModified` | A manual copy changed again | Ask whether to retain/rebaseline or replace |
| `ManualUpstreamChange` | Crow changed while the copy is manual | Compare the emitted candidate and ask merge/replace/retain |
| `MissingSource` or `MissingInstalledFile` | Registry path is stale or incomplete | Stop and correct the path or decision |

The customized/upstream case produces a latest-template candidate in the temporary directory. It supports a
two-way comparison only; a true three-way merge is unavailable because the old template content is not
stored. Delete the candidate after the decision. Complete the decision with `Resolve`:

- **Replace** installs the latest adapted template and returns the entry to `Auto`.
- **Merge** records the user-reviewed merged file and changes the entry to `Manual`.
- **Retain** acknowledges the current upstream version without changing the project file and changes the
  entry to `Manual`. It also accepts that upstream version as reviewed, so that same delta is not raised
  again unless Crow's source changes later.

Use `Unregister` when the project intentionally stops managing or deletes the copied utility. Neither
`Resolve` nor `Unregister` edits registry hashes by hand. If a registry row itself is malformed and prevents
the script from parsing the table, manual deletion of that one row is the recovery path; do not alter hashes
to make an invalid row appear valid.

## Completion rules

- Never overwrite a customized installed file automatically.
- Do not infer provenance from a familiar filename alone.
- Keep the registry row synchronized after install, registration, safe update, or explicit resolution.
- After an update, run the smallest tests that exercise the utility and record any unusual migration
  decision in the testing plan.
