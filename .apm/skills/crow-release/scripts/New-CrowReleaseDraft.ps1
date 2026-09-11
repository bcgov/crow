[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+$')]
    [string]$Version,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-fA-F]{40}$')]
    [string]$CommitSha,

    [string]$RepoRoot = (Resolve-Path (
        [System.IO.Path]::Combine($PSScriptRoot, '..', '..', '..', '..'))).Path,

    [string]$Repository = 'bcgov/crow',

    [string]$OutputDirectory,

    [string]$CandidateDirectory,

    [switch]$PrepareOnly
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

function Get-CheckedCommandOutput {
    param(
        [string]$Command,
        [string[]]$Arguments
    )

    $output = (& $Command @Arguments 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($output)) {
        throw "'$Command $($Arguments -join ' ')' did not return a value."
    }
    return $output
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Content
    )

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false))
}

function Assert-VersionReferences {
    param(
        [string]$Root,
        [string]$ExpectedVersion
    )

    $apmContent = [System.IO.File]::ReadAllText((Join-Path $Root 'apm.yml'))
    if ($apmContent -notmatch '(?m)^version:\s*' + [regex]::Escape($ExpectedVersion) + '\s*$') {
        throw "apm.yml does not declare version $ExpectedVersion."
    }

    $plugin = ConvertFrom-Json -InputObject (
        [System.IO.File]::ReadAllText((Join-Path $Root '.github/plugin/plugin.json')))
    if ($plugin.version -ne $ExpectedVersion) {
        throw ".github/plugin/plugin.json declares version $($plugin.version), expected $ExpectedVersion."
    }

    $readme = [System.IO.File]::ReadAllText((Join-Path $Root 'README.md'))
    $matches = [regex]::Matches(
        $readme,
        'bcgov/crow#v([0-9]+\.[0-9]+\.[0-9]+)|bcgov-crow-([0-9]+\.[0-9]+\.[0-9]+)\.zip')
    if ($matches.Count -eq 0) {
        throw 'README.md contains no release installation or archive references.'
    }

    foreach ($match in $matches) {
        $referencedVersion = $match.Groups[1].Value
        if ([string]::IsNullOrWhiteSpace($referencedVersion)) {
            $referencedVersion = $match.Groups[2].Value
        }
        if ($referencedVersion -ne $ExpectedVersion) {
            throw "README.md contains release reference $referencedVersion, expected $ExpectedVersion."
        }
    }
}

function Assert-ArchivePublic {
    param([string]$ArchivePath)

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
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
}

function Assert-Candidate {
    param(
        [string]$Directory,
        [string]$ExpectedVersion,
        [string]$ExpectedCommitSha
    )

    $metadataPath = Join-Path $Directory 'crow-release-metadata.json'
    $archivePath = Join-Path $Directory "bcgov-crow-$ExpectedVersion.zip"
    $checksumPath = "$archivePath.sha256"
    $notesPath = Join-Path $Directory 'release-notes.md'

    foreach ($path in @($metadataPath, $archivePath, $checksumPath, $notesPath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Release candidate is missing $path."
        }
    }

    $metadata = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($metadataPath))
    if ($metadata.Version -ne $ExpectedVersion -or
        $metadata.CommitSha.ToLowerInvariant() -ne $ExpectedCommitSha.ToLowerInvariant()) {
        throw 'Release candidate metadata does not match the approved version and commit.'
    }

    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash.ToLowerInvariant()
    $checksumParts = ([System.IO.File]::ReadAllText($checksumPath)).Trim() -split '\s+'
    if ($checksumParts.Count -lt 2 -or $checksumParts[0].ToLowerInvariant() -ne $actualHash) {
        throw 'Release candidate checksum does not match its archive.'
    }
    if ($metadata.ArchiveSha256 -ne $actualHash) {
        throw 'Release candidate metadata checksum does not match its archive.'
    }

    $notes = [System.IO.File]::ReadAllText($notesPath)
    if ($metadata.NotesSha256 -and
        $metadata.NotesSha256 -ne (Get-FileHash -Algorithm SHA256 -LiteralPath $notesPath).Hash.ToLowerInvariant()) {
        throw 'Release candidate metadata checksum does not match its notes.'
    }
    if ($notes -match '\{\{[A-Z0-9_]+\}\}' -or $notes -match '(?i)\bhttps?://') {
        throw 'Release candidate notes contain unresolved placeholders or URLs.'
    }
    if ($notes -notmatch '(?m)^# BCGov Crow - v' + [regex]::Escape($ExpectedVersion) + '\s*$') {
        throw 'Release candidate notes have an invalid title.'
    }
}

$root = (Resolve-Path $RepoRoot).Path
$tag = "v$Version"
$outputPath = if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    Join-Path $root 'build'
}
elseif ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory
}
else {
    Join-Path $root $OutputDirectory
}

if (-not (Test-Path -LiteralPath $outputPath)) {
    New-Item -ItemType Directory -Path $outputPath | Out-Null
}
$outputPath = (Resolve-Path $outputPath).Path

$archivePath = Join-Path $outputPath "bcgov-crow-$Version.zip"
$checksumPath = "$archivePath.sha256"
$notesPath = Join-Path $outputPath 'release-notes.md'
$metadataPath = Join-Path $outputPath 'crow-release-metadata.json'
$validatorPath = Join-Path $root '.apm/skills/crow-agent-skill-authoring/scripts/Test-CrowAssets.ps1'
$releaseGuardsPath = Join-Path $root '.apm/skills/crow-release/scripts/Test-CrowReleaseGuards.ps1'
$templatePath = Join-Path $root '.apm/skills/crow-release/templates/release-notes-template.md'

Assert-VersionReferences -Root $root -ExpectedVersion $Version

$headCommit = Get-CheckedCommandOutput -Command 'git' -Arguments @('-C', $root, 'rev-parse', 'HEAD')
if ($headCommit.ToLowerInvariant() -ne $CommitSha.ToLowerInvariant()) {
    throw "HEAD $headCommit does not match the approved commit $CommitSha."
}

$worktreeStatus = @(& git -C $root status --porcelain --untracked-files=all)
if ($LASTEXITCODE -ne 0 -or $worktreeStatus.Count -gt 0) {
    throw 'Release preparation requires a clean Git worktree.'
}

Invoke-CheckedCommand git @('-C', $root, 'fetch', 'origin', 'main', '--no-tags')
$remoteMain = Get-CheckedCommandOutput -Command 'git' -Arguments @('-C', $root, 'rev-parse', 'origin/main')
if ($remoteMain.ToLowerInvariant() -ne $CommitSha.ToLowerInvariant()) {
    throw "origin/main $remoteMain does not match the approved commit $CommitSha."
}

if ($CandidateDirectory) {
    $candidatePath = (Resolve-Path $CandidateDirectory).Path
    Assert-Candidate -Directory $candidatePath -ExpectedVersion $Version -ExpectedCommitSha $CommitSha
}

& $validatorPath -RepoRoot $root -StrictContext
if ($LASTEXITCODE -ne 0) {
    throw 'Crow asset validation failed.'
}

& $releaseGuardsPath
if ($LASTEXITCODE -ne 0) {
    throw 'Crow release guard validation failed.'
}

foreach ($outputFile in @($archivePath, $checksumPath, $notesPath, $metadataPath)) {
    if (Test-Path -LiteralPath $outputFile) {
        Remove-Item -LiteralPath $outputFile -Force
    }
}

$generatedManifestPath = Join-Path $root '.claude-plugin'
$hadGeneratedManifest = Test-Path -LiteralPath $generatedManifestPath
Push-Location $root
try {
    Invoke-CheckedCommand apm @('pack', '--dry-run')
    Invoke-CheckedCommand apm @('pack', '--archive', '--output', $outputPath)
}
finally {
    Pop-Location
    if (-not $hadGeneratedManifest -and (Test-Path -LiteralPath $generatedManifestPath)) {
        Remove-Item -LiteralPath $generatedManifestPath -Recurse -Force
    }
}

if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
    throw "Expected package archive was not created: $archivePath"
}
Assert-ArchivePublic -ArchivePath $archivePath

$archiveHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash.ToLowerInvariant()
Write-Utf8NoBom -Path $checksumPath -Content (
    "$archiveHash  $([System.IO.Path]::GetFileName($archivePath))`n")

if ($CandidateDirectory) {
    $candidateNotesPath = Join-Path $candidatePath 'release-notes.md'
    $notesContent = [System.IO.File]::ReadAllText($candidateNotesPath)
    $candidateMetadata = ConvertFrom-Json -InputObject (
        [System.IO.File]::ReadAllText((Join-Path $candidatePath 'crow-release-metadata.json')))
    $notesContent = $notesContent.Replace($candidateMetadata.ArchiveSha256, $archiveHash)
}
else {
    $notesContent = [System.IO.File]::ReadAllText($templatePath)
    $replacements = @{
        '{{VERSION}}' = $Version
        '{{RELEASE_TYPE}}' = 'Patch release.'
        '{{SUMMARY}}' = 'This patch release adds approval-gated draft release preparation and standardizes release artifacts.'
        '{{HIGHLIGHT_1}}' = 'Added deterministic version, provenance, archive, and checksum validation.'
        '{{HIGHLIGHT_2}}' = 'Added protected-environment draft release preparation after successful main-branch validation.'
        '{{HIGHLIGHT_3}}' = 'Standardized release notes and package artifact handling.'
        '{{CHANGE_1}}' = 'Added a draft-only release operation that never publishes automatically.'
        '{{CHANGE_2}}' = 'Added commit, tag, release, and artifact race-safety checks.'
        '{{ASSET_VALIDATION_RESULT}}' = 'passed with 0 errors and 0 warnings.'
        '{{PACKAGE_DRY_RUN_RESULT}}' = 'passed.'
        '{{ARCHIVE_INSPECTION_RESULT}}' = 'passed; no evidence or local-state entries.'
        '{{ADDITIONAL_VALIDATION}}' = 'Exact version consistency and approved-commit checks passed.'
        '{{SHA256}}' = $archiveHash
        '{{COMPATIBILITY_AND_SCOPE}}' = 'No breaking installation or invocation changes are introduced.'
        '{{UPGRADE_NOTES}}' = "Install the matching v$Version tag. Review the draft release before publishing."
    }
    foreach ($placeholder in $replacements.Keys) {
        $notesContent = $notesContent.Replace($placeholder, $replacements[$placeholder])
    }
}

if ($notesContent -match '\{\{[A-Z0-9_]+\}\}' -or $notesContent -match '(?i)\bhttps?://') {
    throw 'Release notes contain unresolved placeholders or URLs.'
}
if ($notesContent -notmatch '(?m)^# BCGov Crow - v' + [regex]::Escape($Version) + '\s*$') {
    throw 'Release notes have an invalid title.'
}
if ($notesContent -notmatch [regex]::Escape("bcgov-crow-$Version.zip") -or
    $notesContent -notmatch [regex]::Escape($archiveHash)) {
    throw 'Release notes do not identify the exact archive and checksum.'
}
Write-Utf8NoBom -Path $notesPath -Content $notesContent

$metadata = [ordered]@{
    Version = $Version
    Tag = $tag
    CommitSha = $CommitSha.ToLowerInvariant()
    ArchiveName = [System.IO.Path]::GetFileName($archivePath)
    ArchiveSha256 = $archiveHash
    NotesName = [System.IO.Path]::GetFileName($notesPath)
    NotesSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $notesPath).Hash.ToLowerInvariant()
}
Write-Utf8NoBom -Path $metadataPath -Content (
    ($metadata | ConvertTo-Json -Depth 3) + "`n")

if ($PrepareOnly) {
    Write-Host "Release candidate prepared: $outputPath"
    Write-Host "Version: $Version"
    Write-Host "Commit: $CommitSha"
    Write-Host "Archive SHA-256: $archiveHash"
    return
}

if ($null -eq (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI ('gh') is required to create a draft release."
}
Invoke-CheckedCommand gh @('auth', 'status')

& gh release view $tag '--repo' $Repository *> $null
if ($LASTEXITCODE -eq 0) {
    throw "GitHub release '$tag' already exists."
}

$remoteTagOutput = (& git -C $root ls-remote '--exit-code' '--tags' origin "refs/tags/$tag" 2>$null | Out-String).Trim()
$remoteTagExists = $LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($remoteTagOutput)
if ($remoteTagExists) {
    Invoke-CheckedCommand git @('-C', $root, 'fetch', 'origin', "refs/tags/$tag")
    $fetchedTagType = Get-CheckedCommandOutput -Command 'git' -Arguments @('-C', $root, 'cat-file', '-t', 'FETCH_HEAD')
    if ($fetchedTagType -ne 'tag') {
        throw "Remote tag '$tag' is not annotated."
    }
    $remoteTagCommit = Get-CheckedCommandOutput -Command 'git' -Arguments @('-C', $root, 'rev-parse', 'FETCH_HEAD^{}')
    if ($remoteTagCommit.ToLowerInvariant() -ne $CommitSha.ToLowerInvariant()) {
        throw "Remote tag '$tag' does not point to the approved commit."
    }
}
else {
    & git -C $root show-ref --verify --quiet "refs/tags/$tag"
    $localTagExists = $LASTEXITCODE -eq 0
    if ($localTagExists) {
        $localTagType = Get-CheckedCommandOutput -Command 'git' -Arguments @('-C', $root, 'cat-file', '-t', "refs/tags/$tag")
        if ($localTagType -ne 'tag') {
            throw "Existing local tag '$tag' is not annotated."
        }
        $localTagCommit = Get-CheckedCommandOutput -Command 'git' -Arguments @('-C', $root, 'rev-parse', "$tag^{}")
        if ($localTagCommit.ToLowerInvariant() -ne $CommitSha.ToLowerInvariant()) {
            throw "Existing local tag '$tag' does not point to the approved commit."
        }
    }
    else {
        Invoke-CheckedCommand git @('-C', $root, 'tag', '-a', $tag, '-m', "Crow $tag", $CommitSha)
    }

    Invoke-CheckedCommand git @('-C', $root, 'push', 'origin', "refs/tags/$tag")
    Invoke-CheckedCommand git @('-C', $root, 'fetch', 'origin', "refs/tags/$tag")
    $pushedTagType = Get-CheckedCommandOutput -Command 'git' -Arguments @('-C', $root, 'cat-file', '-t', 'FETCH_HEAD')
    if ($pushedTagType -ne 'tag') {
        throw "Pushed tag '$tag' is not annotated."
    }
    $pushedTagCommit = Get-CheckedCommandOutput -Command 'git' -Arguments @('-C', $root, 'rev-parse', 'FETCH_HEAD^{}')
    if ($pushedTagCommit.ToLowerInvariant() -ne $CommitSha.ToLowerInvariant()) {
        throw "Pushed tag '$tag' does not point to the approved commit."
    }
}

Invoke-CheckedCommand gh @(
    'release', 'create', $tag,
    $archivePath,
    $checksumPath,
    '--repo', $Repository,
    '--draft',
    '--verify-tag',
    '--title', "BCGov Crow - v$Version",
    '--notes-file', $notesPath,
    '--fail-on-no-commits')

$releaseJson = Get-CheckedCommandOutput -Command 'gh' -Arguments @(
    'release', 'view', $tag, '--repo', $Repository,
    '--json', 'isDraft,tagName,name,assets')
$release = ConvertFrom-Json -InputObject $releaseJson
if (-not $release.isDraft -or $release.tagName -ne $tag -or
    $release.name -ne "BCGov Crow - v$Version") {
    throw "Draft release '$tag' failed title, tag, or draft-state verification."
}

$expectedAssets = @(
    [System.IO.Path]::GetFileName($archivePath),
    [System.IO.Path]::GetFileName($checksumPath))
$actualAssets = @($release.assets | ForEach-Object { $_.name })
if (@(Compare-Object $expectedAssets $actualAssets).Count -gt 0) {
    throw "Draft release '$tag' does not contain exactly the expected assets."
}

Write-Host "Draft release created and verified: $tag"
