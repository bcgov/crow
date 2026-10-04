[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string]$BaseCommit,

    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path $RepoRoot).Path

function Get-PackageVersion {
    param([string]$Content, [string]$Source)

    if ($Content -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$') {
        throw "Invalid package version in $Source."
    }
    return [version]$Matches[1]
}

& git -C $root cat-file -e "$BaseCommit^{commit}" 2>$null
if ($LASTEXITCODE -ne 0) {
    throw "Base commit $BaseCommit is unavailable; fetch the PR base history."
}

$changedFiles = @(& git -C $root diff --name-only --no-renames $BaseCommit HEAD)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to compare the pull request with its base commit.'
}
$releaseChanges = @($changedFiles | Where-Object {
    $_ -eq 'apm.yml' -or $_ -like '.apm/*' -or $_ -like 'collections/*'
})
if ($releaseChanges.Count -eq 0) {
    Write-Output 'No release-relevant files changed; version bump not required.'
    return
}

$baseContent = @(& git -C $root show "${BaseCommit}:apm.yml")
if ($LASTEXITCODE -ne 0) {
    throw "Unable to read apm.yml from base commit $BaseCommit."
}
$baseVersion = Get-PackageVersion -Content ($baseContent -join "`n") -Source 'base apm.yml'
$proposedContent = @(& git -C $root show 'HEAD:apm.yml')
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to read apm.yml from the proposed commit.'
}
$proposedVersion = Get-PackageVersion -Content ($proposedContent -join "`n") -Source 'proposed apm.yml'

if ($proposedVersion -le $baseVersion) {
    throw "Release-relevant files changed but package version $proposedVersion is not higher than base version $baseVersion. Bump apm.yml and synchronized package references before merging."
}
Write-Output "Release-relevant files changed; package version $baseVersion -> $proposedVersion."
