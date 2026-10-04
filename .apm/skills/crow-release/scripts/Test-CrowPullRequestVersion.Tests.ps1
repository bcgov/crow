[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'Test-CrowPullRequestVersion.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "crow-pr-version-tests-$([guid]::NewGuid())"

function Invoke-Git {
    param([string[]]$Arguments)

    & git -C $tempRoot @Arguments | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed."
    }
}

function Assert-Rejected {
    param([string]$Base, [string]$Expected)

    try {
        & $script -BaseCommit $Base -RepoRoot $tempRoot
    }
    catch {
        if ($_.Exception.Message -match $Expected) {
            return
        }
        throw
    }
    throw "Expected version check to reject: $Expected."
}

try {
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    Invoke-Git @('init', '--initial-branch=main')
    Invoke-Git @('config', 'user.name', 'Crow Tests')
    Invoke-Git @('config', 'user.email', 'crow-tests@example.invalid')
    New-Item -ItemType Directory -Path (Join-Path $tempRoot '.apm') | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $tempRoot 'apm.yml'), "name: crow-test`nversion: 0.11.4`n")
    [System.IO.File]::WriteAllText((Join-Path $tempRoot '.apm/example.md'), "original`n")
    Invoke-Git @('add', '.')
    Invoke-Git @('commit', '-m', 'Base version')
    $base = (& git -C $tempRoot rev-parse HEAD).Trim()

    [System.IO.File]::WriteAllText((Join-Path $tempRoot '.apm/example.md'), "changed`n")
    Invoke-Git @('add', '.')
    Invoke-Git @('commit', '-m', 'Change package without bump')
    Assert-Rejected -Base $base -Expected 'not higher than base version'

    [System.IO.File]::WriteAllText((Join-Path $tempRoot 'apm.yml'), "name: crow-test`nversion: 0.11.3`n")
    Invoke-Git @('add', 'apm.yml')
    Invoke-Git @('commit', '-m', 'Propose older version')
    Assert-Rejected -Base $base -Expected 'not higher than base version'

    [System.IO.File]::WriteAllText((Join-Path $tempRoot 'apm.yml'), "name: crow-test`nversion: 0.11.5`n")
    Invoke-Git @('add', 'apm.yml')
    Invoke-Git @('commit', '-m', 'Bump version')
    & $script -BaseCommit $base -RepoRoot $tempRoot

    [System.IO.File]::WriteAllText((Join-Path $tempRoot 'apm.yml'), "name: crow-test`nversion: 0.11.4`n")
    [System.IO.File]::WriteAllText((Join-Path $tempRoot '.apm/example.md'), "original`n")
    Invoke-Git @('add', '.')
    Invoke-Git @('commit', '-m', 'Restore base package')
    [System.IO.File]::WriteAllText((Join-Path $tempRoot 'README.md'), "docs only`n")
    Invoke-Git @('add', '.')
    Invoke-Git @('commit', '-m', 'Docs only')
    & $script -BaseCommit $base -RepoRoot $tempRoot

    $collection = Join-Path $tempRoot 'collections/starter-package'
    New-Item -ItemType Directory -Path $collection -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $collection 'README.md'), "collection update`n")
    Invoke-Git @('add', '.')
    Invoke-Git @('commit', '-m', 'Change collection without bump')
    Assert-Rejected -Base $base -Expected 'not higher than base version'

    Write-Output 'Passed: changed package requires a higher version; unrelated change does not.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

exit 0
