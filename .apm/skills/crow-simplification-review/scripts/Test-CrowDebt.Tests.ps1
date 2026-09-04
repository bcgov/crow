[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$powerShellExecutable = (Get-Process -Id $PID).Path
$scannerPath = Join-Path $PSScriptRoot 'Get-CrowDebt.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "crow-debt-$([guid]::NewGuid().ToString('N'))")

function Write-TestFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, $Content)
}

function Join-TestPath {
    param(
        [Parameter(Mandatory)][string[]]$Parts
    )

    $path = $Parts[0]
    foreach ($part in $Parts[1..($Parts.Count - 1)]) {
        $path = Join-Path $path $part
    }
    return $path
}

try {
    $projectRoot = Join-Path $tempRoot 'project'
    Write-TestFile (Join-TestPath @($projectRoot, 'src', 'markers.ps1')) @'
# crow-debt: shortcut; bounded adapter; ceiling: one provider; revisit: provider count changes; owner: team; status: accepted
# TODO: replace when the native adapter is available
# crow-debt: shortcut; incomplete metadata
# crow-debt: shortcut; revisit: provider count changes
'@
    Write-TestFile (Join-TestPath @($projectRoot, 'src', 'inline.ps1')) '$value = 1 # Future: remove temporary value'
    Write-TestFile (Join-TestPath @($projectRoot, 'sql', 'schema.sql')) '-- To-Do: verify the migration consumer'
    Write-TestFile (Join-TestPath @($projectRoot, 'docs', 'comments.md')) @'
<!-- FIXME: update the public example -->
~~~text
// TODO: this fenced example is not a finding
~~~
'@
    Write-TestFile (Join-TestPath @($projectRoot, 'docs', 'Crow-debt.md')) '# crow-debt: shortcut; ledger example'
    Write-TestFile (Join-TestPath @($projectRoot, 'evidence', 'ignored.ps1')) '# TODO: ignored evidence'
    Write-TestFile (Join-TestPath @($projectRoot, 'build', 'ignored.ps1')) '# TODO: ignored build output'

    Push-Location $projectRoot
    try {
        $output = (& $powerShellExecutable -NoProfile -File $scannerPath 2>&1 | Out-String)
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    if ($exitCode -ne 0) {
        throw "Scanner exited $exitCode. Output: $output"
    }
    foreach ($expected in @(
        'Crow debt markers',
        'src/markers.ps1:L1',
        'tracked',
        'no-trigger',
        'incomplete',
        'General debt comments',
        'TODO',
        'To-Do',
        'FUTURE',
        'FIXME'
    )) {
        if ($output -notmatch [regex]::Escape($expected)) {
            throw "Scanner output did not contain '$expected'. Output: $output"
        }
    }
    foreach ($unexpected in @(
        'fenced example',
        'ignored evidence',
        'ignored build output',
        'docs/Crow-debt.md'
    )) {
        if ($output -match [regex]::Escape($unexpected)) {
            throw "Scanner output incorrectly contained '$unexpected'. Output: $output"
        }
    }

    'Crow debt scanner tests passed.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
