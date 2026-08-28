[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+$')]
    [string]$Version,

    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path,

    [string]$Branch = 'main',

    [string]$Repository = 'bcgov/crow',

    [switch]$Publish,

    [switch]$ConfirmMajor
)

$ErrorActionPreference = 'Stop'

function Invoke-CheckedCommand {
    param(
        [string]$Command,
        [string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "'$Command $($Arguments -join ' ')' failed with exit code $LASTEXITCODE."
    }
}

$root = (Resolve-Path $RepoRoot).Path
$tag = "v$Version"
$apmPath = Join-Path $root 'apm.yml'
$validatorPath = Join-Path $PSScriptRoot '..\..\crow-agent-skill-authoring\scripts\Test-CrowAssets.ps1'
$buildPath = Join-Path $root 'build'
$archivePath = Join-Path $buildPath "bcgov-crow-$Version.zip"
$checksumPath = "$archivePath.sha256"

$apmContent = [System.IO.File]::ReadAllText($apmPath)
if ($apmContent -notmatch '(?m)^version:\s*' + [regex]::Escape($Version) + '\s*$') {
    throw "apm.yml does not declare version $Version."
}

$versionTags = @(& git -C $root tag --list 'v[0-9]*' --sort=-v:refname)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to inspect Git tags.'
}
$latestVersionTag = @($versionTags | Select-Object -First 1)

$newMajor = [int]($Version.Split('.')[0])
if ($latestVersionTag.Count -gt 0) {
    $previousVersion = $latestVersionTag[0].TrimStart('v')
    $previousMajor = [int]($previousVersion.Split('.')[0])
    if ($newMajor -gt $previousMajor -and -not $ConfirmMajor) {
        throw "Publishing major version $Version requires an explicit user decision and the -ConfirmMajor switch."
    }
}
elseif ($newMajor -gt 0 -and -not $ConfirmMajor) {
    throw "Publishing the first major version requires an explicit user decision and the -ConfirmMajor switch."
}

$worktreeStatus = @(& git -C $root status --porcelain)
if ($LASTEXITCODE -ne 0 -or $worktreeStatus.Count -gt 0) {
    throw 'Release packaging requires a clean Git worktree.'
}

$currentBranch = (& git -C $root branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $currentBranch -ne $Branch) {
    throw "Release packaging must run on branch '$Branch'; current branch is '$currentBranch'."
}

Invoke-CheckedCommand git @('-C', $root, 'fetch', 'origin', $Branch, '--tags')
$headCommit = (& git -C $root rev-parse 'HEAD').Trim()
$remoteCommit = (& git -C $root rev-parse "origin/$Branch").Trim()
if ($headCommit -ne $remoteCommit) {
    throw "HEAD $headCommit does not match origin/$Branch $remoteCommit."
}

$tagCommit = (& git -C $root rev-list -n 1 $tag 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($tagCommit)) {
    throw "Create and push annotated tag '$tag' before packaging the release."
}
if ($tagCommit.Trim() -ne $headCommit) {
    throw "Tag '$tag' does not point to HEAD."
}
Invoke-CheckedCommand git @('-C', $root, 'ls-remote', '--exit-code', '--tags', 'origin', "refs/tags/$tag")

& $validatorPath -RepoRoot $root -StrictContext
if ($LASTEXITCODE -ne 0) {
    throw 'Crow asset validation failed.'
}

Push-Location $root
try {
    Invoke-CheckedCommand apm @('pack', '--dry-run')

    if (-not (Test-Path $buildPath)) {
        New-Item -ItemType Directory -Path $buildPath | Out-Null
    }
    foreach ($outputPath in @($archivePath, $checksumPath)) {
        if (Test-Path $outputPath) {
            Remove-Item -LiteralPath $outputPath -Force
        }
    }

    Invoke-CheckedCommand apm @('pack', '--archive', '--output', $buildPath)
}
finally {
    Pop-Location
}

if (-not (Test-Path $archivePath)) {
    throw "Expected package archive was not created: $archivePath"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    $unsafeEntries = @($archive.Entries | Where-Object {
        $normalized = $_.FullName.Replace('\', '/')
        $normalized -match '(^|/)evidence/' -or
        $normalized -match '(^|/)(research|transcripts?)/' -or
        $normalized -match '(^|/)(\.git|\.codebase-memory|build)/'
    })
    if ($unsafeEntries.Count -gt 0) {
        throw "Archive contains non-public evidence or local state: $($unsafeEntries.FullName -join ', ')"
    }
}
finally {
    $archive.Dispose()
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash.ToLowerInvariant()
[System.IO.File]::WriteAllText(
    $checksumPath,
    "$hash  $([System.IO.Path]::GetFileName($archivePath))`n",
    [System.Text.Encoding]::ASCII)

if (-not $Publish) {
    Write-Host "Package ready: $archivePath"
    Write-Host "Checksum: $checksumPath"
    Write-Host "Dry run only. Obtain explicit user approval, then rerun with -Publish."
    return
}

if ($null -eq (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI ('gh') is required to publish a release."
}
Invoke-CheckedCommand gh @('auth', 'status')

& gh release view $tag '--repo' $Repository *> $null
if ($LASTEXITCODE -eq 0) {
    throw "GitHub release '$tag' already exists."
}

Invoke-CheckedCommand gh @(
    'release', 'create', $tag,
    $archivePath,
    $checksumPath,
    '--repo', $Repository,
    '--verify-tag',
    '--generate-notes',
    '--fail-on-no-commits'
)
Invoke-CheckedCommand gh @('release', 'view', $tag, '--repo', $Repository)
