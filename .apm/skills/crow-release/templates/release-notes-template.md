# BCGov Crow - v{{VERSION}}

## Release type

{{RELEASE_TYPE}}

## Summary

{{SUMMARY}}

## Highlights

{{HIGHLIGHTS}}

## Changes

{{CHANGES}}

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
