[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$releaseScript = Join-Path $PSScriptRoot 'Publish-CrowRelease.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "crow-release-tests-$([guid]::NewGuid())"

function Invoke-Git {
    param(
        [string]$Repo,
        [string[]]$Arguments
    )

    & git -C $Repo @Arguments | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
}

function New-TestRepository {
    param([string]$Version)

    $repo = Join-Path $tempRoot ([guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $repo | Out-Null
    Invoke-Git $repo @('init', '--initial-branch=main')
    Invoke-Git $repo @('config', 'user.name', 'Crow Tests')
    Invoke-Git $repo @('config', 'user.email', 'crow-tests@example.invalid')
    [System.IO.File]::WriteAllText(
        (Join-Path $repo 'apm.yml'),
        "name: crow-test`nversion: $Version`n",
        [System.Text.UTF8Encoding]::new($false))
    Invoke-Git $repo @('add', 'apm.yml')
    Invoke-Git $repo @('commit', '-m', 'Initial test package')
    return $repo
}

function Assert-ThrowsLike {
    param(
        [scriptblock]$Action,
        [string]$Pattern,
        [string]$Scenario
    )

    try {
        & $Action
    }
    catch {
        if ($_.Exception.Message -match $Pattern) {
            Write-Host "Passed: $Scenario"
            return
        }
        throw "$Scenario failed with unexpected error: $($_.Exception.Message)"
    }

    throw "$Scenario did not fail as expected."
}

try {
    New-Item -ItemType Directory -Path $tempRoot | Out-Null

    $majorRepo = New-TestRepository '1.0.0'
    Invoke-Git $majorRepo @('tag', '-a', 'v0.3.0', '-m', 'Previous release')
    Invoke-Git $majorRepo @('tag', '-a', 'v1.0.0', '-m', 'Target release')
    Assert-ThrowsLike {
        & $releaseScript -Version '1.0.0' -RepoRoot $majorRepo
    } 'requires an explicit user decision' 'Target tag is excluded from previous-version selection'

    $lightweightRepo = New-TestRepository '0.3.1'
    Invoke-Git $lightweightRepo @('tag', 'v0.3.1')
    Assert-ThrowsLike {
        & $releaseScript -Version '0.3.1' -RepoRoot $lightweightRepo
    } 'annotated tag' 'Lightweight release tag is rejected'
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
