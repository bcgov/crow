[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path (Get-Location) 'crow.config')
)

$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()

function Add-ConfigError {
    param([string]$Message)
    $errors.Add($Message)
}

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    Add-ConfigError "Configuration file was not found: $ConfigPath"
}
else {
    $content = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $ConfigPath).Path)
    $requiredSections = @(
        'spec_version:',
        '^project:',
        '^sonar:',
        '^ci_cd:',
        '^work_tracking:',
        '^related_repositories:',
        '^documentation:',
        '^memory_policy:'
    )

    foreach ($section in $requiredSections) {
        if ($content -notmatch "(?m)$section") {
            Add-ConfigError "Required config section is missing: $section"
        }
    }

    if ($content -match '(?im)https?://|ftp://') {
        Add-ConfigError 'URLs are not allowed in the public crow.config manifest.'
    }
    if ($content -match '(?im)^\s*[^#\r\n]*(?:[A-Za-z]:[\\/]|\\\\|\.\.[\\/])' -or
        $content -match '(?m)^\s*/') {
        Add-ConfigError 'Absolute paths and parent-directory traversal are not allowed.'
    }
    if ($content -match '(?im)^\s*(?:token|password|secret|api[_-]?key)\s*:') {
        Add-ConfigError 'Credential-bearing keys are not allowed in crow.config.'
    }

    foreach ($line in ($content -split "`r?`n")) {
        if ($line -match '^\s+[A-Za-z][A-Za-z0-9_-]*_ref:\s*(.+?)\s*$') {
            $value = $Matches[1].Trim().Trim('"', "'")
            if ($value -notmatch '^(?:raven|crow):[A-Za-z0-9][A-Za-z0-9._:-]*$') {
                Add-ConfigError "Reference values must use raven: or crow: names: $value"
            }
        }
        if ($line -match '^\s+path:\s*(.+?)\s*$') {
            $value = $Matches[1].Trim().Trim('"', "'")
            if ($value -match '^(?:[A-Za-z]:[\\/]|[\\/]|~[\\/])' -or
                $value -match '(^|[\\/])\.\.([\\/]|$)') {
                Add-ConfigError "Documentation paths must be repository-relative: $value"
            }
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "Crow config validation passed: $ConfigPath"
