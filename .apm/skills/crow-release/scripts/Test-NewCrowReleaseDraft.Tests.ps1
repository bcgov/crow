[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "crow-release-draft-tests-$([guid]::NewGuid())"
$remoteRoot = Join-Path ([System.IO.Path]::GetTempPath()) "crow-release-draft-remote-$([guid]::NewGuid()).git"
$testVersion = '0.7.1'
$testTag = "v$testVersion"
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
            Write-Output '{"isDraft":true,"tagName":"v0.7.1","name":"BCGov Crow - v0.7.1","assets":[{"name":"bcgov-crow-0.7.1.zip"},{"name":"bcgov-crow-0.7.1.zip.sha256"}]}'
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
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    & git clone --local $sourceRoot $tempRoot | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to create the release test checkout.'
    }
    Invoke-Git $tempRoot @('switch', '-C', 'main')

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

    Invoke-Git $tempRoot @('config', 'user.name', 'Crow Release Tests')
    Invoke-Git $tempRoot @('config', 'user.email', 'crow-release-tests@example.invalid')
    Invoke-Git $tempRoot @('add', '-A')
    Invoke-Git $tempRoot @('commit', '-m', 'Test release draft')
    $commitSha = (& git -C $tempRoot rev-parse HEAD).Trim()

    & git init --bare $remoteRoot | Out-Null
    Invoke-Git $tempRoot @('remote', 'set-url', 'origin', $remoteRoot)
    Invoke-Git $tempRoot @('push', '--set-upstream', 'origin', 'main')

    $outputDirectory = Join-Path $tempRoot 'build/candidate'
    $testScript = Join-Path $tempRoot '.apm/skills/crow-release/scripts/New-CrowReleaseDraft.ps1'
    & $testScript -Version $testVersion -CommitSha $commitSha -RepoRoot $tempRoot `
        -OutputDirectory $outputDirectory -PrepareOnly

    $metadataPath = Join-Path $outputDirectory 'crow-release-metadata.json'
    $metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    if ($metadata.Version -ne $testVersion -or $metadata.CommitSha -ne $commitSha.ToLowerInvariant()) {
        throw 'Candidate metadata does not match the test release.'
    }
    Write-Host 'Passed: prepares a candidate with exact provenance'

    Assert-ThrowsLike {
        & $testScript -Version $testVersion -CommitSha ('0' * 40) -RepoRoot $tempRoot `
            -OutputDirectory (Join-Path $tempRoot 'build/mismatch') -PrepareOnly
    } 'HEAD .* does not match' 'Rejects a mismatched commit'

    $tamperedCandidate = Join-Path $tempRoot 'build/tampered'
    Copy-Item -LiteralPath $outputDirectory -Destination $tamperedCandidate -Recurse
    [System.IO.File]::WriteAllText(
        (Join-Path $tamperedCandidate 'bcgov-crow-0.7.1.zip.sha256'),
        ("$('0' * 64)  bcgov-crow-0.7.1.zip`n"))
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
    $tagCommit = (& git -C $tempRoot rev-parse 'v0.7.1^{}').Trim()
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
    Remove-Item Function:\apm -ErrorAction SilentlyContinue
    Remove-Item Function:\gh -ErrorAction SilentlyContinue
}
