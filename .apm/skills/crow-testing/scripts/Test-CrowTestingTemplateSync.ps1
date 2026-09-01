[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$powerShellExecutable = (Get-Process -Id $PID).Path
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "crow-template-sync-$([guid]::NewGuid().ToString('N'))")

function Invoke-SyncCase {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Script,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][int]$ExpectedExit,
        [string]$ExpectedText
    )

    $previousErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = (& $powerShellExecutable -NoProfile -File $Script @Arguments 2>&1 | Out-String)
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($exitCode -ne $ExpectedExit) {
        throw "$Name expected exit $ExpectedExit, got $exitCode. Output: $output"
    }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedText) -and
        $output -notmatch [regex]::Escape($ExpectedText)) {
        throw "$Name did not emit '$ExpectedText'. Output: $output"
    }
}

try {
    $skillRoot = Join-Path $tempRoot 'skill'
    $projectRoot = Join-Path $tempRoot 'project'
    $scriptRoot = Join-Path $skillRoot 'scripts'
    $templateRoot = Join-Path $skillRoot 'templates'
    $generatorRoot = Join-Path $templateRoot 'dotnet\generators'
    $planRoot = Join-Path $projectRoot 'docs\testing'
    New-Item -ItemType Directory -Path $scriptRoot, $generatorRoot, $planRoot -Force | Out-Null

    Copy-Item (Join-Path $PSScriptRoot 'Sync-CrowTestingTemplate.ps1') $scriptRoot
    Copy-Item (Join-Path $PSScriptRoot '..\templates\dotnet\generators\*.cs') $generatorRoot
    Copy-Item (Join-Path $PSScriptRoot '..\templates\testing-plan-template.md') (
        Join-Path $planRoot 'testing-plan.md')

    $script = Join-Path $scriptRoot 'Sync-CrowTestingTemplate.ps1'
    $source = Join-Path $generatorRoot 'GenCharExtensions.cs'
    $plan = Join-Path $planRoot 'testing-plan.md'
    foreach ($template in Get-ChildItem $generatorRoot -Filter '*.cs') {
        $templateContent = [System.IO.File]::ReadAllText($template.FullName)
        if (([regex]::Matches($templateContent, 'namespace YourProject\.Tests\.Generators')).Count -ne 1) {
            throw "$($template.Name) does not contain exactly one adaptable namespace."
        }
        if ($templateContent -match 'crow-testing') {
            throw "$($template.Name) contains Crow provenance."
        }
    }

    $mixedPlan = ([System.IO.File]::ReadAllText($plan)).Replace("`r`n", "`n")
    $mixedPlan = $mixedPlan.Replace("# Testing Plan`n", "# Testing Plan`r`n")
    [System.IO.File]::WriteAllText($plan, $mixedPlan, [System.Text.UTF8Encoding]::new($true))
    $targetRelative = 'tests\Example.Tests\Generators\GenCharExtensions.cs'
    $installed = Join-Path $projectRoot $targetRelative
    $common = @('-TargetRepo', $projectRoot)

    Invoke-SyncCase -Name 'path escape rejection' -Script $script -ExpectedExit 1 -ExpectedText 'escapes its allowed root' -Arguments (
        @(
            '-Action', 'Install',
            '-TemplateId', 'escape',
            '-Source', 'dotnet/generators/GenCharExtensions.cs',
            '-TargetPath', '..\escape.cs',
            '-Namespace', 'Example.Tests.Generators'
        ) + $common)
    Invoke-SyncCase -Name 'reserved namespace rejection' -Script $script -ExpectedExit 1 -ExpectedText 'reserved C# keyword' -Arguments (
        @(
            '-Action', 'Install',
            '-TemplateId', 'bad-namespace',
            '-Source', 'dotnet/generators/GenCharExtensions.cs',
            '-TargetPath', 'tests\bad.cs',
            '-Namespace', 'Example.class'
        ) + $common)

    Invoke-SyncCase -Name 'install' -Script $script -ExpectedExit 0 -ExpectedText 'Installed' -Arguments (
        @(
            '-Action', 'Install',
            '-TemplateId', 'example-gen-char',
            '-Source', 'dotnet/generators/GenCharExtensions.cs',
            '-TargetPath', $targetRelative,
            '-Namespace', 'Example.Tests.Generators'
        ) + $common)
    if (([System.IO.File]::ReadAllText($installed)) -match 'crow-testing') {
        throw 'Installed output contains Crow provenance.'
    }
    $planBytes = [System.IO.File]::ReadAllBytes($plan)
    if ($planBytes[0] -ne 0xEF -or $planBytes[1] -ne 0xBB -or $planBytes[2] -ne 0xBF) {
        throw 'Testing-plan UTF-8 BOM was not preserved.'
    }
    $preservedPlan = [System.IO.File]::ReadAllText($plan)
    if (-not $preservedPlan.StartsWith("# Testing Plan`r`n") -or
        $preservedPlan -notmatch "## Start here: guides`n") {
        throw 'Testing-plan line terminators outside the registry were not preserved.'
    }
    Invoke-SyncCase -Name 'same source distinct target' -Script $script -ExpectedExit 0 -ExpectedText 'Installed' -Arguments (
        @(
            '-Action', 'Install',
            '-TemplateId', 'second-gen-char',
            '-Source', 'dotnet/generators/GenCharExtensions.cs',
            '-TargetPath', 'tests\Second.Tests\Generators\GenCharExtensions.cs',
            '-Namespace', 'Second.Class.Generators'
        ) + $common)
    Invoke-SyncCase -Name 'duplicate installed path rejection' -Script $script -ExpectedExit 1 -ExpectedText 'same installed path' -Arguments (
        @(
            '-Action', 'Register',
            '-TemplateId', 'duplicate-gen-char',
            '-Source', 'dotnet/generators/GenCharExtensions.cs',
            '-TargetPath', $targetRelative,
            '-Namespace', 'Example.Tests.Generators'
        ) + $common)
    Invoke-SyncCase -Name 'current' -Script $script -ExpectedExit 0 -ExpectedText 'Current' -Arguments (
        @('-Action', 'Audit') + $common)

    $installedContent = [System.IO.File]::ReadAllText($installed)
    [System.IO.File]::WriteAllText($installed, $installedContent.Replace("`r`n", "`n"))
    Invoke-SyncCase -Name 'line-ending normalization' -Script $script -ExpectedExit 0 -ExpectedText 'Current' -Arguments (
        @('-Action', 'Audit') + $common)

    [System.IO.File]::AppendAllText($source, "`n// upstream change")
    Invoke-SyncCase -Name 'safe update available' -Script $script -ExpectedExit 0 -ExpectedText 'SafeUpdateAvailable' -Arguments (
        @('-Action', 'Audit') + $common)
    Invoke-SyncCase -Name 'safe update' -Script $script -ExpectedExit 0 -ExpectedText 'Updated' -Arguments (
        @('-Action', 'Update') + $common)

    [System.IO.File]::AppendAllText($installed, "`n// project-only customization")
    $customizedBytes = [System.IO.File]::ReadAllBytes($installed)
    Invoke-SyncCase -Name 'project-only customization audit' -Script $script -ExpectedExit 3 -ExpectedText 'Customized' -Arguments (
        @('-Action', 'Audit', '-TemplateId', 'example-gen-char') + $common)
    Invoke-SyncCase -Name 'project-only customization refusal' -Script $script -ExpectedExit 3 -ExpectedText 'user action is required' -Arguments (
        @('-Action', 'Update', '-TemplateId', 'example-gen-char') + $common)
    if ([System.Convert]::ToBase64String($customizedBytes) -ne
        [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($installed))) {
        throw 'Update changed a customized installed file.'
    }
    Invoke-SyncCase -Name 'customization replace' -Script $script -ExpectedExit 0 -ExpectedText 'ResolvedReplace' -Arguments (
        @('-Action', 'Resolve', '-TemplateId', 'example-gen-char', '-Resolution', 'Replace') + $common)

    [System.IO.File]::AppendAllText($installed, "`n// project customization")
    [System.IO.File]::AppendAllText($source, "`n// second upstream change")
    Invoke-SyncCase -Name 'dual drift' -Script $script -ExpectedExit 3 -ExpectedText 'user action is required' -Arguments (
        @('-Action', 'Audit') + $common)
    $candidatesBefore = @(Get-ChildItem ([System.IO.Path]::GetTempPath()) -Filter '*.GenCharExtensions.cs.crow-latest' |
        ForEach-Object FullName)
    Invoke-SyncCase -Name 'candidate' -Script $script -ExpectedExit 3 -ExpectedText 'Resolve with Replace, Merge, or Retain' -Arguments (
        @('-Action', 'Update') + $common)
    $newCandidates = @(Get-ChildItem ([System.IO.Path]::GetTempPath()) -Filter '*.GenCharExtensions.cs.crow-latest' |
        Where-Object { $_.FullName -notin $candidatesBefore })
    if ($newCandidates.Count -ne 1) {
        throw 'Customized update did not report its temporary candidate path.'
    }
    Remove-Item -LiteralPath $newCandidates[0].FullName -Force
    Invoke-SyncCase -Name 'merge resolution' -Script $script -ExpectedExit 0 -ExpectedText 'ResolvedMerge' -Arguments (
        @('-Action', 'Resolve', '-TemplateId', 'example-gen-char', '-Resolution', 'Merge') + $common)
    Invoke-SyncCase -Name 'manual current' -Script $script -ExpectedExit 0 -ExpectedText 'ManualCurrent' -Arguments (
        @('-Action', 'Audit') + $common)

    [System.IO.File]::AppendAllText($source, "`n// third upstream change")
    Invoke-SyncCase -Name 'manual upstream change' -Script $script -ExpectedExit 3 -ExpectedText 'ManualUpstreamChange' -Arguments (
        @('-Action', 'Audit') + $common)
    Invoke-SyncCase -Name 'retain resolution' -Script $script -ExpectedExit 0 -ExpectedText 'ResolvedRetain' -Arguments (
        @('-Action', 'Resolve', '-TemplateId', 'example-gen-char', '-Resolution', 'Retain') + $common)
    Invoke-SyncCase -Name 'manual after retain' -Script $script -ExpectedExit 0 -ExpectedText 'ManualCurrent' -Arguments (
        @('-Action', 'Audit') + $common)
    [System.IO.File]::AppendAllText($source, "`n// fourth upstream change")
    Invoke-SyncCase -Name 'replace resolution' -Script $script -ExpectedExit 0 -ExpectedText 'ResolvedReplace' -Arguments (
        @('-Action', 'Resolve', '-TemplateId', 'example-gen-char', '-Resolution', 'Replace') + $common)
    Invoke-SyncCase -Name 'auto after replace' -Script $script -ExpectedExit 0 -ExpectedText 'Current' -Arguments (
        @('-Action', 'Audit') + $common)

    $planContent = [System.IO.File]::ReadAllText($plan)
    $formattedPlan = $planContent.Replace(
        '|---|---|---|---|---|---|---|',
        '| :--- | ---: | --- | --- | --- | --- | --- |')
    [System.IO.File]::WriteAllText($plan, $formattedPlan)
    Invoke-SyncCase -Name 'formatted markdown table' -Script $script -ExpectedExit 0 -ExpectedText 'Current' -Arguments (
        @('-Action', 'Audit') + $common)

    Invoke-SyncCase -Name 'unregister' -Script $script -ExpectedExit 0 -ExpectedText 'Unregistered' -Arguments (
        @('-Action', 'Unregister', '-TemplateId', 'example-gen-char') + $common)

    $badRoot = Join-Path $tempRoot 'bad-project'
    New-Item -ItemType Directory -Path (Join-Path $badRoot 'docs\testing') -Force | Out-Null
    Copy-Item (Join-Path $PSScriptRoot '..\templates\testing-plan-template.md') (
        Join-Path $badRoot 'docs\testing\testing-plan.md')
    $badPlan = Join-Path $badRoot 'docs\testing\testing-plan.md'
    [System.IO.File]::WriteAllText(
        $badPlan,
        ([System.IO.File]::ReadAllText($badPlan)).Replace(
            '|---|---|---|---|---|---|---|',
            '|---|---|'))
    Invoke-SyncCase -Name 'malformed registry' -Script $script -ExpectedExit 1 -ExpectedText 'separator is missing or malformed' -Arguments @(
        '-Action', 'Audit',
        '-TargetRepo', $badRoot)

    $eofRoot = Join-Path $tempRoot 'eof-project'
    New-Item -ItemType Directory -Path (Join-Path $eofRoot 'docs\testing') -Force | Out-Null
    $eofPlan = Join-Path $eofRoot 'docs\testing\testing-plan.md'
    $eofContent = @(
        '# Testing Plan',
        '',
        '## Managed Crow templates',
        '',
        '| Template ID | Source | Installed path | Namespace | Mode | Source SHA-256 | Installed SHA-256 |',
        '|---|---|---|---|---|---|---|') -join "`n"
    [System.IO.File]::WriteAllText($eofPlan, $eofContent, [System.Text.UTF8Encoding]::new($false))
    Invoke-SyncCase -Name 'EOF registry install' -Script $script -ExpectedExit 0 -ExpectedText 'Installed' -Arguments @(
        '-Action', 'Install',
        '-TargetRepo', $eofRoot,
        '-TemplateId', 'eof-gen-char',
        '-Source', 'dotnet/generators/GenCharExtensions.cs',
        '-TargetPath', 'tests\GenCharExtensions.cs',
        '-Namespace', 'Eof.Tests.Generators')
    Invoke-SyncCase -Name 'EOF registry audit' -Script $script -ExpectedExit 0 -ExpectedText 'Current' -Arguments @(
        '-Action', 'Audit',
        '-TargetRepo', $eofRoot)

    Write-Host 'Crow testing template synchronization checks passed.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
