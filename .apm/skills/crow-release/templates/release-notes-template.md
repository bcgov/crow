# BCGov Crow - v{{VERSION}}

## Release type

{{RELEASE_TYPE}}

## Summary

{{SUMMARY}}

## Highlights

- {{HIGHLIGHT_1}}
- {{HIGHLIGHT_2}}
- {{HIGHLIGHT_3}}

## Changes

- {{CHANGE_1}}
- {{CHANGE_2}}

## Validation

- Crow asset validation: {{ASSET_VALIDATION_RESULT}}
- Package dry run: {{PACKAGE_DRY_RUN_RESULT}}
- Archive inspection: {{ARCHIVE_INSPECTION_RESULT}}
- Additional checks: {{ADDITIONAL_VALIDATION}}

## Artifacts

- Archive: `bcgov-crow-{{VERSION}}.zip`
- SHA-256 file: `bcgov-crow-{{VERSION}}.zip.sha256`
- SHA-256: `{{SHA256}}`

## Installation

Install the tagged release globally:

```powershell
apm install bcgov/crow#v{{VERSION}} --global --target copilot
```

Or install the packaged archive:

```powershell
apm install .\build\bcgov-crow-{{VERSION}}.zip --global --target copilot
```

## Compatibility and scope

{{COMPATIBILITY_AND_SCOPE}}

## Upgrade notes

{{UPGRADE_NOTES}}
