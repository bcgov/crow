[CmdletBinding(DefaultParameterSetName = 'File')]
param(
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+$')]
    [string]$Version,

    [string]$RepoRoot = (Resolve-Path (
        [System.IO.Path]::Combine($PSScriptRoot, '..', '..', '..', '..'))).Path,

    [Parameter(ParameterSetName = 'File')]
    [string]$ReleaseNotesPath,

    [Parameter(Mandatory, ParameterSetName = 'Content')]
    [AllowEmptyString()]
    [string]$NotesContent,

    [ValidatePattern('^[0-9a-fA-F]{64}$')]
    [string]$ArchiveSha256
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Version)) {
    $manifest = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'apm.yml'))
    if ($manifest -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$') {
        throw 'Unable to resolve the release version from apm.yml.'
    }
    $Version = $Matches[1]
}

if ($PSCmdlet.ParameterSetName -eq 'File') {
    if ([string]::IsNullOrWhiteSpace($ReleaseNotesPath)) {
        $ReleaseNotesPath = Join-Path $RepoRoot ".github/release-notes/v$Version.md"
    }
    if (-not (Test-Path -LiteralPath $ReleaseNotesPath -PathType Leaf)) {
        throw "Reviewed release notes are missing at $ReleaseNotesPath."
    }
    $NotesContent = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $ReleaseNotesPath).Path)
}

if ([string]::IsNullOrWhiteSpace($ArchiveSha256)) {
    if (([regex]::Matches($NotesContent, '\{\{SHA256\}\}')).Count -ne 1) {
        throw 'Reviewed release notes must contain exactly one {{SHA256}} token.'
    }
    $ArchiveSha256 = '0' * 64
    $NotesContent = $NotesContent.Replace('{{VERSION}}', $Version).Replace('{{SHA256}}', $ArchiveSha256)
}

if ($NotesContent -match '\{\{[^{}]+\}\}' -or $NotesContent -match '(?i)\bhttps?://') {
    throw 'Release notes contain unresolved placeholders or URLs.'
}
if ($NotesContent -notmatch '(?m)^# BCGov Crow - v' + [regex]::Escape($Version) + '\s*$') {
    throw 'Release notes have an invalid title.'
}

$archiveName = "bcgov-crow-$Version.zip"
if (-not $NotesContent.Contains($archiveName) -or
    -not $NotesContent.Contains("$archiveName.sha256") -or
    -not $NotesContent.Contains($ArchiveSha256)) {
    throw 'Release notes do not identify the exact archive and checksum.'
}

Write-Host "Release notes validated for v$Version."
