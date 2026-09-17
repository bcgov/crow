[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "crow-release-draft-tests-$([guid]::NewGuid())"
$remoteRoot = Join-Path ([System.IO.Path]::GetTempPath()) "crow-release-draft-remote-$([guid]::NewGuid()).git"
$reviewedNotesPath = Join-Path ([System.IO.Path]::GetTempPath()) "crow-release-notes-$([guid]::NewGuid()).md"
$testVersion = (Get-Content (Join-Path $sourceRoot 'apm.yml') |
    Select-String '^version:' |
    ForEach-Object { $_.Line -replace '^version:\s*', '' }).Trim()
if ($testVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
    throw "Unable to resolve a semantic package version from $sourceRoot\apm.yml."
}
$testTag = "v$testVersion"
$testArchiveName = "bcgov-crow-$testVersion.zip"
$fakeReleaseCreated = $false

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

function Assert-ReviewedReleaseNotes {
    param(
        [string]$Root,
        [string]$ExpectedVersion
    )

    $notesPath = Join-Path $Root ".github/release-notes/v$ExpectedVersion.md"
    if (-not (Test-Path -LiteralPath $notesPath -PathType Leaf)) {
        throw "Reviewed release notes are missing at $notesPath."
    }

    $notes = [System.IO.File]::ReadAllText($notesPath)
    $archiveName = "bcgov-crow-$ExpectedVersion.zip"
    $checksumName = "$archiveName.sha256"
    $codeSpan = [string][char]0x60
    $shaReference = "$codeSpan{{SHA256}}$codeSpan"

    if ($notes -notmatch "(?m)^# BCGov Crow - v$([regex]::Escape($ExpectedVersion))\s*$") {
        throw "Reviewed release notes have an invalid title: $notesPath."
    }
    if (-not $notes.Contains("$codeSpan$archiveName$codeSpan") -or
        -not $notes.Contains("$codeSpan$checksumName$codeSpan")) {
        throw "Reviewed release notes do not identify the exact archive and checksum file: $notesPath."
    }
    if (([regex]::Matches($notes, [regex]::Escape($shaReference))).Count -ne 1) {
        throw "Reviewed release notes must contain exactly one $shaReference token: $notesPath."
    }

    Write-Host 'Passed: checked-in release notes use the exact archive and checksum contract'
}

function global:apm {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    if ($Arguments -contains '--dry-run') {
        $global:LASTEXITCODE = 0
        return
    }

    if ($Arguments -contains '--archive') {
        $outputIndex = [array]::IndexOf($Arguments, '--output')
        if ($outputIndex -lt 0 -or $outputIndex + 1 -ge $Arguments.Count) {
            throw 'Fake APM archive call did not specify an output directory.'
        }
        $outputDirectory = $Arguments[$outputIndex + 1]
        $version = (Get-Content (Join-Path (Get-Location) 'apm.yml') |
            Select-String '^version:' |
            ForEach-Object { $_.Line -replace '^version:\s*', '' }).Trim()
        $archivePath = Join-Path $outputDirectory "bcgov-crow-$version.zip"
        if (-not (Test-Path -LiteralPath $outputDirectory)) {
            New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
        }
        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [System.IO.Compression.ZipFile]::Open(
            $archivePath,
            [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            $entry = $archive.CreateEntry('plugin.json')
            $writer = [System.IO.StreamWriter]::new($entry.Open())
            try {
                $writer.Write('{}')
            }
            finally {
                $writer.Dispose()
            }
        }
        finally {
            $archive.Dispose()
        }
        $global:LASTEXITCODE = 0
        return
    }

    throw "Unexpected fake APM command: $($Arguments -join ' ')"
}

function global:gh {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)

    if ($Arguments[0] -eq 'auth' -and $Arguments[1] -eq 'status') {
        $global:LASTEXITCODE = 0
        return
    }
    if ($Arguments[0] -eq 'release' -and $Arguments[1] -eq 'view') {
        if (-not $global:fakeReleaseCreated) {
            $global:LASTEXITCODE = 1
            return
        }
        if ($Arguments -contains '--json') {
            $tag = $Arguments[2]
            $version = $tag -replace '^v', ''
            $release = [ordered]@{
                isDraft = $true
                tagName = $tag
                name = "BCGov Crow - v$version"
                assets = @(
                    [ordered]@{ name = "bcgov-crow-$version.zip" }
                    [ordered]@{ name = "bcgov-crow-$version.zip.sha256" }
                )
            }
            Write-Output ($release | ConvertTo-Json -Compress)
        }
        $global:LASTEXITCODE = 0
        return
    }
    if ($Arguments[0] -eq 'release' -and $Arguments[1] -eq 'create') {
        $global:fakeReleaseCreated = $true
        $global:LASTEXITCODE = 0
        return
    }

    throw "Unexpected fake GitHub CLI command: $($Arguments -join ' ')"
}

try {
    Assert-ReviewedReleaseNotes -Root $sourceRoot -ExpectedVersion $testVersion

    # Build an independent fixture so the CI checkout's shallow history is not pushed.
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    & git -C $tempRoot init | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to initialize the release test checkout.'
    }
    Invoke-Git $tempRoot @('checkout', '-b', 'main')

    $sourceFiles = @(& git -C $sourceRoot ls-files --cached --others --exclude-standard)
    if ($LASTEXITCODE -ne 0 -or $sourceFiles.Count -eq 0) {
        throw 'Unable to enumerate source files for the release test checkout.'
    }
    foreach ($relativePath in $sourceFiles) {
        $sourcePath = Join-Path $sourceRoot $relativePath
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            continue
        }

        $targetPath = Join-Path $tempRoot $relativePath
        $targetParent = Split-Path -Parent $targetPath
        if (-not (Test-Path -LiteralPath $targetParent)) {
            New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
        }
        Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
    }
    Invoke-Git $tempRoot @('config', 'user.name', 'Crow Release Tests')
    Invoke-Git $tempRoot @('config', 'user.email', 'crow-release-tests@example.invalid')
    Invoke-Git $tempRoot @('add', '-A')
    Invoke-Git $tempRoot @('commit', '-m', 'Test fixture base')

    $copiedFiles = @(
        '.apm/skills/crow-release/scripts/New-CrowReleaseDraft.ps1',
        '.apm/skills/crow-release/templates',
        '.github/plugin/plugin.json',
        '.github/workflows/crow-release-draft.yml',
        'README.md',
        'apm.yml'
    )
    foreach ($relativePath in $copiedFiles) {
        $sourcePath = Join-Path $sourceRoot $relativePath
        $targetPath = Join-Path $tempRoot $relativePath
        $targetParent = Split-Path -Parent $targetPath
        if (-not (Test-Path -LiteralPath $targetParent)) {
            New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
        }
        Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Recurse -Force
    }

    Add-Content -LiteralPath (Join-Path $tempRoot '.github/workflows/crow-release-draft.yml') `
        -Value '# release-note generation fixture change'
    Invoke-Git $tempRoot @('add', '-A')
    Invoke-Git $tempRoot @('commit', '--allow-empty', '-m', 'Test release draft')
    $commitSha = (& git -C $tempRoot rev-parse HEAD).Trim()

    & git init --bare $remoteRoot | Out-Null
    Invoke-Git $tempRoot @('remote', 'add', 'origin', $remoteRoot)
    Invoke-Git $tempRoot @('push', '--set-upstream', 'origin', 'main')

    [System.IO.File]::WriteAllText($reviewedNotesPath, @'
# BCGov Crow - v{{VERSION}}

## Release type

Patch release

## Summary

Reviewed release notes supplied by the release author.

## Highlights

- Describes the user-facing outcome of the validated release changes.

## Changes

- Includes the reviewed release details rather than commit subjects.

## Validation

- Crow asset validation: passed.
- Package dry run: passed.
- Archive inspection: passed.
- Additional checks: passed.

## Artifacts

- Archive: `bcgov-crow-{{VERSION}}.zip`
- SHA-256 file: `bcgov-crow-{{VERSION}}.zip.sha256`
- SHA-256: `{{SHA256}}`

## Installation

Install the packaged archive with APM.
'@)

    $outputDirectory = Join-Path $tempRoot 'build/candidate'
    $testScript = Join-Path $tempRoot '.apm/skills/crow-release/scripts/New-CrowReleaseDraft.ps1'
    & $testScript -Version $testVersion -CommitSha $commitSha -RepoRoot $tempRoot `
        -OutputDirectory $outputDirectory -ReleaseNotesPath $reviewedNotesPath -PrepareOnly

    $metadataPath = Join-Path $outputDirectory 'crow-release-metadata.json'
    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    if ($metadata.Version -ne $testVersion -or $metadata.CommitSha -ne $commitSha.ToLowerInvariant()) {
        throw 'Candidate metadata does not match the test release.'
    }
    $notes = Get-Content -LiteralPath (Join-Path $outputDirectory 'release-notes.md') -Raw
    if ($notes -notmatch 'Reviewed release notes supplied by the release author' -or
        $notes -match 'Compatibility and scope|Upgrade notes') {
        throw 'Reviewed release notes were not preserved.'
    }
    Write-Host 'Passed: prepares a candidate with reviewed release notes'

    Assert-ThrowsLike {
        & $testScript -Version $testVersion -CommitSha $commitSha -RepoRoot $tempRoot `
            -OutputDirectory (Join-Path $tempRoot 'build/missing-notes') -PrepareOnly
    } 'ReleaseNotesPath is required' 'Rejects missing reviewed notes'

    Assert-ThrowsLike {
        & $testScript -Version $testVersion -CommitSha ('0' * 40) -RepoRoot $tempRoot `
            -OutputDirectory (Join-Path $tempRoot 'build/mismatch') -PrepareOnly
    } 'HEAD .* does not match' 'Rejects a mismatched commit'

    $tamperedCandidate = Join-Path $tempRoot 'build/tampered'
    Copy-Item -LiteralPath $outputDirectory -Destination $tamperedCandidate -Recurse
    [System.IO.File]::WriteAllText(
        (Join-Path $tamperedCandidate "$testArchiveName.sha256"),
        ("$('0' * 64)  $testArchiveName`n"))
    Assert-ThrowsLike {
        & $testScript -Version $testVersion -CommitSha $commitSha -RepoRoot $tempRoot `
            -OutputDirectory (Join-Path $tempRoot 'build/tampered-final') `
            -CandidateDirectory $tamperedCandidate
    } 'checksum' 'Rejects a tampered candidate'

    Invoke-Git $tempRoot @('tag', $testTag)
    Assert-ThrowsLike {
        & $testScript -Version $testVersion -CommitSha $commitSha -RepoRoot $tempRoot `
            -OutputDirectory (Join-Path $tempRoot 'build/lightweight-final') `
            -CandidateDirectory $outputDirectory
    } 'not annotated' 'Rejects an existing lightweight tag'
    Invoke-Git $tempRoot @('tag', '-d', $testTag)

    Invoke-Git $tempRoot @('tag', '-a', $testTag, 'HEAD^', '-m', 'Wrong commit')
    Assert-ThrowsLike {
        & $testScript -Version $testVersion -CommitSha $commitSha -RepoRoot $tempRoot `
            -OutputDirectory (Join-Path $tempRoot 'build/wrong-tag-final') `
            -CandidateDirectory $outputDirectory
    } 'does not point to the approved commit' 'Rejects a tag pointing to another commit'
    Invoke-Git $tempRoot @('tag', '-d', $testTag)

    $global:fakeReleaseCreated = $true
    Assert-ThrowsLike {
        & $testScript -Version $testVersion -CommitSha $commitSha -RepoRoot $tempRoot `
            -OutputDirectory (Join-Path $tempRoot 'build/duplicate-final') `
            -CandidateDirectory $outputDirectory
    } 'already exists' 'Rejects an existing GitHub release'
    $global:fakeReleaseCreated = $false

    & $testScript -Version $testVersion -CommitSha $commitSha -RepoRoot $tempRoot `
        -OutputDirectory (Join-Path $tempRoot 'build/final') `
        -CandidateDirectory $outputDirectory
    $tagCommit = (& git -C $tempRoot rev-parse "$testTag^{}").Trim()
    if (-not $global:fakeReleaseCreated -or $tagCommit -ne $commitSha) {
        throw 'Draft release verification did not create the expected annotated tag.'
    }
    Write-Host 'Passed: creates and verifies an annotated draft release'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
    if (Test-Path -LiteralPath $remoteRoot) {
        Remove-Item -LiteralPath $remoteRoot -Recurse -Force
    }
    if (Test-Path -LiteralPath $reviewedNotesPath) {
        Remove-Item -LiteralPath $reviewedNotesPath -Force
    }
    Remove-Item Function:\apm -ErrorAction SilentlyContinue
    Remove-Item Function:\gh -ErrorAction SilentlyContinue
}

exit 0
