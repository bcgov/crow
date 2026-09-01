<#
.SYNOPSIS
Installs, registers, audits, resolves, or safely updates ready-to-copy crow-testing templates.

.DESCRIPTION
Uses two normalized-content SHA-256 fingerprints stored in docs/testing/testing-plan.md: the untouched
bundled template and the namespace-adapted installed file. Automatic updates apply only to Auto-managed
files that still match their recorded installed fingerprint. Invoke this script as a separate PowerShell
process when consuming its exit code: 0 is success, 3 requires a user decision, and 1 is failure.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Install', 'Register', 'Audit', 'Update', 'Resolve', 'Unregister')]
    [string]$Action,

    [string]$TargetRepo = (Get-Location).Path,
    [string]$TestingPlanPath = 'docs/testing/testing-plan.md',
    [string]$TemplateId,
    [string]$Source,
    [string]$TargetPath,
    [string]$Namespace,

    [ValidateSet('Replace', 'Merge', 'Retain')]
    [string]$Resolution
)

$ErrorActionPreference = 'Stop'
trap {
    Write-Error $_
    exit 1
}

$templateRoot = (Resolve-Path (Join-Path (Join-Path $PSScriptRoot '..') 'templates')).Path
$registryHeading = '## Managed Crow templates'
$registryColumns = @(
    'Template ID',
    'Source',
    'Installed path',
    'Namespace',
    'Mode',
    'Source SHA-256',
    'Installed SHA-256'
)
$placeholderNamespace = 'YourProject.Tests.Generators'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$actionRequired = $false
$reservedCSharpKeywords = @(
    'abstract', 'as', 'base', 'bool', 'break', 'byte', 'case', 'catch', 'char', 'checked', 'class',
    'const', 'continue', 'decimal', 'default', 'delegate', 'do', 'double', 'else', 'enum', 'event',
    'explicit', 'extern', 'false', 'finally', 'fixed', 'float', 'for', 'foreach', 'goto', 'if',
    'implicit', 'in', 'int', 'interface', 'internal', 'is', 'lock', 'long', 'namespace', 'new',
    'null', 'object', 'operator', 'out', 'override', 'params', 'private', 'protected', 'public',
    'readonly', 'ref', 'return', 'sbyte', 'sealed', 'short', 'sizeof', 'stackalloc', 'static',
    'string', 'struct', 'switch', 'this', 'throw', 'true', 'try', 'typeof', 'uint', 'ulong',
    'unchecked', 'unsafe', 'ushort', 'using', 'virtual', 'void', 'volatile', 'while')

function Assert-SafeField {
    param(
        [Parameter(Mandatory)][string]$Value,
        [Parameter(Mandatory)][string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -match '[\x00-\x1F\x7F|]') {
        throw "$Name is empty or contains a control or pipe character."
    }
}

function Convert-RelativeSeparators {
    param([Parameter(Mandatory)][string]$Path)

    $separator = [System.IO.Path]::DirectorySeparatorChar
    return $Path.Replace('\', $separator).Replace('/', $separator)
}

function Get-ContainedPath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$Description
    )

    Assert-SafeField -Value $RelativePath -Name $Description
    $normalizedRelative = Convert-RelativeSeparators -Path $RelativePath
    if ([System.IO.Path]::IsPathRooted($normalizedRelative)) {
        throw "$Description must be relative: $RelativePath"
    }

    $rootPath = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $rootPath $normalizedRelative))
    $comparison = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') {
        [System.StringComparison]::OrdinalIgnoreCase
    }
    else {
        [System.StringComparison]::Ordinal
    }
    $prefix = $rootPath + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($prefix, $comparison)) {
        throw "$Description escapes its allowed root: $RelativePath"
    }

    $current = $rootPath
    foreach ($part in $normalizedRelative.Split(
        @([System.IO.Path]::DirectorySeparatorChar),
        [System.StringSplitOptions]::RemoveEmptyEntries)) {
        $current = Join-Path $current $part
        if (Test-Path -LiteralPath $current) {
            $attributes = [System.IO.File]::GetAttributes($current)
            if (($attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "$Description traverses a symbolic link or reparse point: $current"
            }
        }
    }

    return $fullPath
}

function Convert-ToNormalizedText {
    param([Parameter(Mandatory)][string]$Content)

    return $Content.Replace("`r`n", "`n").Replace("`r", "`n")
}

function Get-TextHash {
    param([Parameter(Mandatory)][string]$Content)

    $bytes = $utf8NoBom.GetBytes((Convert-ToNormalizedText -Content $Content))
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($algorithm.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $algorithm.Dispose()
    }
}

function Get-FileTextHash {
    param([Parameter(Mandatory)][string]$Path)

    return Get-TextHash -Content ([System.IO.File]::ReadAllText($Path))
}

function Get-AdaptedTemplateContent {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$TargetNamespace
    )

    Assert-SafeField -Value $TargetNamespace -Name 'Namespace'
    if ($TargetNamespace -notmatch '^@?[A-Za-z_][A-Za-z0-9_]*(\.@?[A-Za-z_][A-Za-z0-9_]*)*$') {
        throw "Namespace is not a supported C# namespace: $TargetNamespace"
    }
    foreach ($segment in $TargetNamespace.Split('.')) {
        if (-not $segment.StartsWith('@') -and $reservedCSharpKeywords -ccontains $segment) {
            throw "Namespace segment '$segment' is a reserved C# keyword; escape it with @ or choose another name."
        }
    }

    $content = [System.IO.File]::ReadAllText($SourcePath)
    $needle = "namespace $placeholderNamespace"
    $declarationCount = ([regex]::Matches($content, [regex]::Escape($needle))).Count
    if ($declarationCount -ne 1) {
        throw "Template must contain exactly one '$needle' declaration; found $declarationCount in $SourcePath."
    }

    return $content.Replace($needle, "namespace $TargetNamespace")
}

function Split-MarkdownRow {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Line)

    if (-not $Line.TrimStart().StartsWith('|')) {
        return @()
    }
    return @($Line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
}

function Get-Registry {
    param([Parameter(Mandatory)][string]$PlanPath)

    if (-not (Test-Path -LiteralPath $PlanPath -PathType Leaf)) {
        throw "Testing plan not found: $PlanPath"
    }

    $rawBytes = [System.IO.File]::ReadAllBytes($PlanPath)
    $hasUtf8Bom = $rawBytes.Length -ge 3 -and
        $rawBytes[0] -eq 0xEF -and $rawBytes[1] -eq 0xBB -and $rawBytes[2] -eq 0xBF
    $rawContent = [System.IO.File]::ReadAllText($PlanPath)
    $segments = @(
        [regex]::Matches($rawContent, '([^\r\n]*)(\r\n|\r|\n|$)') |
            Where-Object { $_.Groups[1].Value.Length -gt 0 -or $_.Groups[2].Value.Length -gt 0 } |
            ForEach-Object {
                [pscustomobject]@{
                    Text = $_.Groups[1].Value
                    Ending = $_.Groups[2].Value
                }
            })
    $lines = @($segments | ForEach-Object Text)
    $headingIndex = -1
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index].Trim() -eq $registryHeading) {
            $headingIndex = $index
            break
        }
    }
    if ($headingIndex -lt 0) {
        throw "Testing plan is missing the '$registryHeading' section."
    }

    $headerIndex = -1
    for ($index = $headingIndex + 1; $index -lt $lines.Count; $index++) {
        $cells = Split-MarkdownRow -Line $lines[$index]
        if ($cells.Count -eq $registryColumns.Count) {
            $headerMatches = $true
            for ($cellIndex = 0; $cellIndex -lt $registryColumns.Count; $cellIndex++) {
                if ($cells[$cellIndex] -ne $registryColumns[$cellIndex]) {
                    $headerMatches = $false
                    break
                }
            }
            if ($headerMatches) {
                $headerIndex = $index
                break
            }
        }
        if ($lines[$index].TrimStart().StartsWith('## ')) {
            break
        }
    }
    if ($headerIndex -lt 0 -or $headerIndex + 1 -ge $lines.Count) {
        throw 'Managed-template registry header is missing or malformed.'
    }

    $separatorCells = Split-MarkdownRow -Line $lines[$headerIndex + 1]
    if ($separatorCells.Count -ne $registryColumns.Count -or
        @($separatorCells | Where-Object { $_ -notmatch '^:?-{3,}:?$' }).Count -gt 0) {
        throw 'Managed-template registry separator is missing or malformed.'
    }

    $entries = [System.Collections.Generic.List[object]]::new()
    $rowIndex = $headerIndex + 2
    while ($rowIndex -lt $lines.Count -and $lines[$rowIndex].TrimStart().StartsWith('|')) {
        $cells = Split-MarkdownRow -Line $lines[$rowIndex]
        if ($cells.Count -ne $registryColumns.Count) {
            throw "Malformed managed-template registry row at line $($rowIndex + 1)."
        }

        if (-not [string]::IsNullOrWhiteSpace($cells[0])) {
            foreach ($cell in $cells) {
                Assert-SafeField -Value $cell -Name "Registry value at line $($rowIndex + 1)"
            }
            if ($cells[4] -notin @('Auto', 'Manual')) {
                throw "Invalid managed-template mode at line $($rowIndex + 1): $($cells[4])"
            }
            if ($cells[5] -notmatch '^[a-f0-9]{64}$' -or $cells[6] -notmatch '^[a-f0-9]{64}$') {
                throw "Invalid SHA-256 value in managed-template registry row at line $($rowIndex + 1)."
            }

            $entries.Add([pscustomobject]@{
                TemplateId = $cells[0]
                Source = $cells[1]
                InstalledPath = $cells[2]
                Namespace = $cells[3]
                Mode = $cells[4]
                SourceHash = $cells[5]
                InstalledHash = $cells[6]
            })
        }
        $rowIndex++
    }

    $duplicates = @($entries | Group-Object TemplateId | Where-Object Count -gt 1)
    if ($duplicates.Count -gt 0) {
        throw "Duplicate managed-template ID: $($duplicates[0].Name)"
    }

    $prefix = [string]::Join('', @(
        $segments[0..($headerIndex + 1)] | ForEach-Object { $_.Text + $_.Ending }))
    $suffix = if ($rowIndex -lt $segments.Count) {
        [string]::Join('', @(
            $segments[$rowIndex..($segments.Count - 1)] | ForEach-Object { $_.Text + $_.Ending }))
    }
    else {
        ''
    }
    $rowNewLine = $segments[$headerIndex + 1].Ending
    if ([string]::IsNullOrEmpty($rowNewLine)) {
        $rowNewLine = [System.Environment]::NewLine
        $prefix += $rowNewLine
    }

    return [pscustomobject]@{
        Entries = $entries
        Prefix = $prefix
        Suffix = $suffix
        RowNewLine = $rowNewLine
        HasUtf8Bom = $hasUtf8Bom
    }
}

function Set-BytesAtomic {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][byte[]]$Bytes
    )

    $temporaryPath = Join-Path (Split-Path -Parent $Path) (
        ".$([System.IO.Path]::GetFileName($Path)).$([guid]::NewGuid().ToString('N')).tmp")
    try {
        [System.IO.File]::WriteAllBytes($temporaryPath, $Bytes)
        Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Set-TextAtomic {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    Set-BytesAtomic -Path $Path -Bytes $utf8NoBom.GetBytes($Content)
}

function Save-Registry {
    param(
        [Parameter(Mandatory)][string]$PlanPath,
        [Parameter(Mandatory)]$Registry,
        [Parameter(Mandatory)]$Entries
    )

    $rows = [System.Collections.Generic.List[string]]::new()

    if ($Entries.Count -eq 0) {
        $rows.Add('| | | | | | | |')
    }
    else {
        foreach ($entry in @($Entries | Sort-Object TemplateId)) {
            foreach ($property in @(
                'TemplateId', 'Source', 'InstalledPath', 'Namespace', 'Mode', 'SourceHash', 'InstalledHash')) {
                Assert-SafeField -Value ([string]$entry.$property) -Name "Registry $property"
            }
            $rows.Add(
                "| $($entry.TemplateId) | $($entry.Source) | $($entry.InstalledPath) | " +
                "$($entry.Namespace) | $($entry.Mode) | $($entry.SourceHash) | $($entry.InstalledHash) |")
        }
    }

    $content = $Registry.Prefix
    foreach ($row in $rows) {
        $content += $row + $Registry.RowNewLine
    }
    $content += $Registry.Suffix

    $bytes = $utf8NoBom.GetBytes($content)
    if ($Registry.HasUtf8Bom) {
        $preamble = $utf8NoBom.GetPreamble()
        if ($preamble.Length -eq 0) {
            $preamble = [byte[]](0xEF, 0xBB, 0xBF)
        }
        $combined = [byte[]]::new($preamble.Length + $bytes.Length)
        [System.Array]::Copy($preamble, 0, $combined, 0, $preamble.Length)
        [System.Array]::Copy($bytes, 0, $combined, $preamble.Length, $bytes.Length)
        $bytes = $combined
    }
    Set-BytesAtomic -Path $PlanPath -Bytes $bytes
}

function Get-EntryState {
    param(
        [Parameter(Mandatory)]$Entry,
        [Parameter(Mandatory)][string]$RepoRoot
    )

    $sourcePath = Get-ContainedPath -Root $templateRoot -RelativePath $Entry.Source -Description 'Template source'
    $installedPath = Get-ContainedPath -Root $RepoRoot -RelativePath $Entry.InstalledPath -Description 'Installed path'
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        return [pscustomobject]@{ Status = 'MissingSource'; SourcePath = $sourcePath; InstalledPath = $installedPath }
    }
    if (-not (Test-Path -LiteralPath $installedPath -PathType Leaf)) {
        return [pscustomobject]@{ Status = 'MissingInstalledFile'; SourcePath = $sourcePath; InstalledPath = $installedPath }
    }

    $currentSourceHash = Get-FileTextHash -Path $sourcePath
    $currentInstalledHash = Get-FileTextHash -Path $installedPath
    $sourceChanged = $currentSourceHash -ne $Entry.SourceHash
    $installedChanged = $currentInstalledHash -ne $Entry.InstalledHash
    if ($Entry.Mode -eq 'Manual') {
        $status = if ($sourceChanged) {
            'ManualUpstreamChange'
        }
        elseif ($installedChanged) {
            'ManualModified'
        }
        else {
            'ManualCurrent'
        }
    }
    else {
        $status = if ($sourceChanged -and $installedChanged) {
            'CustomizedWithUpstreamChange'
        }
        elseif ($sourceChanged) {
            'SafeUpdateAvailable'
        }
        elseif ($installedChanged) {
            'Customized'
        }
        else {
            'Current'
        }
    }

    return [pscustomobject]@{
        Status = $status
        SourcePath = $sourcePath
        InstalledPath = $installedPath
        CurrentSourceHash = $currentSourceHash
        CurrentInstalledHash = $currentInstalledHash
    }
}

function Write-LatestCandidate {
    param(
        [Parameter(Mandatory)]$Entry,
        [Parameter(Mandatory)]$State
    )

    $candidatePath = Join-Path ([System.IO.Path]::GetTempPath()) (
        "$([guid]::NewGuid().ToString('N')).$([System.IO.Path]::GetFileName($Entry.Source)).crow-latest")
    $adaptedContent = Get-AdaptedTemplateContent -SourcePath $State.SourcePath -TargetNamespace $Entry.Namespace
    [System.IO.File]::WriteAllText($candidatePath, $adaptedContent, $utf8NoBom)
    return $candidatePath
}

function Get-RequiredEntry {
    param(
        [Parameter(Mandatory)]$Registry,
        [Parameter(Mandatory)][string]$Id
    )

    Assert-SafeField -Value $Id -Name 'TemplateId'
    $matchingEntries = @($Registry.Entries | Where-Object TemplateId -eq $Id)
    if ($matchingEntries.Count -eq 0) {
        throw "Template ID is not registered: $Id"
    }
    return $matchingEntries[0]
}

function Assert-UniqueInstalledPaths {
    param(
        [Parameter(Mandatory)]$Entries,
        [Parameter(Mandatory)][string]$RepoRoot
    )

    $comparer = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') {
        [System.StringComparer]::OrdinalIgnoreCase
    }
    else {
        [System.StringComparer]::Ordinal
    }
    $paths = [System.Collections.Generic.HashSet[string]]::new($comparer)
    foreach ($entry in $Entries) {
        $canonicalPath = Get-ContainedPath `
            -Root $RepoRoot `
            -RelativePath $entry.InstalledPath `
            -Description "Installed path for $($entry.TemplateId)"
        if (-not $paths.Add($canonicalPath)) {
            throw "Multiple managed-template entries reference the same installed path: $canonicalPath"
        }
    }
}

$repoRoot = (Resolve-Path $TargetRepo).Path
$planFullPath = Get-ContainedPath -Root $repoRoot -RelativePath $TestingPlanPath -Description 'Testing plan path'
$registry = Get-Registry -PlanPath $planFullPath
Assert-UniqueInstalledPaths -Entries $registry.Entries -RepoRoot $repoRoot

if ($Action -in @('Install', 'Register')) {
    foreach ($required in @(
        @{ Name = 'TemplateId'; Value = $TemplateId },
        @{ Name = 'TargetPath'; Value = $TargetPath },
        @{ Name = 'Namespace'; Value = $Namespace }
    )) {
        Assert-SafeField -Value $required.Value -Name $required.Name
    }
    if ($TemplateId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        throw 'TemplateId may contain only letters, digits, periods, underscores, and hyphens.'
    }
    if (@($registry.Entries | Where-Object TemplateId -eq $TemplateId).Count -gt 0) {
        throw "Template ID is already registered: $TemplateId"
    }

    $sourceRelative = $Source
    if ([string]::IsNullOrWhiteSpace($sourceRelative)) {
        if (-not $TemplateId.EndsWith('.cs', [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'Source is required when TemplateId is not the template filename.'
        }
        $sourceRelative = "dotnet/generators/$TemplateId"
    }
    Assert-SafeField -Value $sourceRelative -Name 'Source'

    $sourcePath = Get-ContainedPath -Root $templateRoot -RelativePath $sourceRelative -Description 'Template source'
    $installedPath = Get-ContainedPath -Root $repoRoot -RelativePath $TargetPath -Description 'Installed path'
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Template source not found: $sourcePath"
    }

    $adaptedContent = Get-AdaptedTemplateContent -SourcePath $sourcePath -TargetNamespace $Namespace
    $createdTarget = $false
    if ($Action -eq 'Install') {
        if (Test-Path -LiteralPath $installedPath) {
            throw "Install target already exists: $installedPath"
        }
        $parent = Split-Path -Parent $installedPath
        if (-not (Test-Path -LiteralPath $parent)) {
            [System.IO.Directory]::CreateDirectory($parent) | Out-Null
        }
        Set-TextAtomic -Path $installedPath -Content $adaptedContent
        $createdTarget = $true
    }
    else {
        if (-not (Test-Path -LiteralPath $installedPath -PathType Leaf)) {
            throw "Register target not found: $installedPath"
        }
        if ((Get-FileTextHash -Path $installedPath) -ne (Get-TextHash -Content $adaptedContent)) {
            throw 'Existing file does not match the current template after namespace and line-ending normalization; reconcile it before registration.'
        }
    }

    $entry = [pscustomobject]@{
        TemplateId = $TemplateId
        Source = $sourceRelative.Replace('\', '/')
        InstalledPath = $TargetPath.Replace('\', '/')
        Namespace = $Namespace
        Mode = 'Auto'
        SourceHash = Get-FileTextHash -Path $sourcePath
        InstalledHash = Get-FileTextHash -Path $installedPath
    }
    $registry.Entries.Add($entry)
    try {
        Assert-UniqueInstalledPaths -Entries $registry.Entries -RepoRoot $repoRoot
        Save-Registry -PlanPath $planFullPath -Registry $registry -Entries $registry.Entries
    }
    catch {
        if ($createdTarget -and (Test-Path -LiteralPath $installedPath)) {
            Remove-Item -LiteralPath $installedPath -Force
        }
        throw
    }
    [pscustomobject]@{ TemplateId = $TemplateId; Status = if ($Action -eq 'Install') { 'Installed' } else { 'Registered' } }
    return
}

if ($Action -in @('Resolve', 'Unregister')) {
    if ([string]::IsNullOrWhiteSpace($TemplateId)) {
        throw "TemplateId is required for $Action."
    }
    $entry = Get-RequiredEntry -Registry $registry -Id $TemplateId
    if ($Action -eq 'Unregister') {
        $remaining = @($registry.Entries | Where-Object TemplateId -ne $TemplateId)
        Save-Registry -PlanPath $planFullPath -Registry $registry -Entries $remaining
        [pscustomobject]@{ TemplateId = $TemplateId; Status = 'Unregistered' }
        return
    }
    if ([string]::IsNullOrWhiteSpace($Resolution)) {
        throw 'Resolution is required for Resolve.'
    }

    $state = Get-EntryState -Entry $entry -RepoRoot $repoRoot
    if ($state.Status -in @('MissingSource', 'MissingInstalledFile')) {
        throw "Cannot resolve $TemplateId while its state is $($state.Status)."
    }
    if ($state.Status -in @('Current', 'ManualCurrent')) {
        throw "Template $TemplateId has no drift to resolve."
    }

    if ($Resolution -eq 'Replace') {
        $oldBytes = [System.IO.File]::ReadAllBytes($state.InstalledPath)
        $oldSourceHash = $entry.SourceHash
        $oldInstalledHash = $entry.InstalledHash
        $oldMode = $entry.Mode
        try {
            $adaptedContent = Get-AdaptedTemplateContent -SourcePath $state.SourcePath -TargetNamespace $entry.Namespace
            Set-TextAtomic -Path $state.InstalledPath -Content $adaptedContent
            $entry.SourceHash = Get-FileTextHash -Path $state.SourcePath
            $entry.InstalledHash = Get-FileTextHash -Path $state.InstalledPath
            $entry.Mode = 'Auto'
            Save-Registry -PlanPath $planFullPath -Registry $registry -Entries $registry.Entries
        }
        catch {
            Set-BytesAtomic -Path $state.InstalledPath -Bytes $oldBytes
            $entry.SourceHash = $oldSourceHash
            $entry.InstalledHash = $oldInstalledHash
            $entry.Mode = $oldMode
            throw
        }
    }
    else {
        $entry.SourceHash = Get-FileTextHash -Path $state.SourcePath
        $entry.InstalledHash = Get-FileTextHash -Path $state.InstalledPath
        $entry.Mode = 'Manual'
        Save-Registry -PlanPath $planFullPath -Registry $registry -Entries $registry.Entries
    }

    [pscustomobject]@{ TemplateId = $TemplateId; Status = "Resolved$Resolution"; Mode = $entry.Mode }
    return
}

$selectedEntries = if ([string]::IsNullOrWhiteSpace($TemplateId)) {
    @($registry.Entries)
}
else {
    @(Get-RequiredEntry -Registry $registry -Id $TemplateId)
}

foreach ($entry in $selectedEntries) {
    $state = Get-EntryState -Entry $entry -RepoRoot $repoRoot
    if ($Action -eq 'Audit') {
        [pscustomobject]@{ TemplateId = $entry.TemplateId; Status = $state.Status; Mode = $entry.Mode }
        if ($state.Status -in @(
            'Customized',
            'CustomizedWithUpstreamChange',
            'ManualModified',
            'ManualUpstreamChange',
            'MissingSource',
            'MissingInstalledFile')) {
            Write-Warning "$($entry.TemplateId): $($state.Status); user action is required."
            $actionRequired = $true
        }
        continue
    }

    switch ($state.Status) {
        'Current' {
            [pscustomobject]@{ TemplateId = $entry.TemplateId; Status = 'Current'; Mode = $entry.Mode }
        }
        'ManualCurrent' {
            [pscustomobject]@{ TemplateId = $entry.TemplateId; Status = 'ManualCurrent'; Mode = $entry.Mode }
        }
        'SafeUpdateAvailable' {
            $oldBytes = [System.IO.File]::ReadAllBytes($state.InstalledPath)
            $oldSourceHash = $entry.SourceHash
            $oldInstalledHash = $entry.InstalledHash
            try {
                $adaptedContent = Get-AdaptedTemplateContent -SourcePath $state.SourcePath -TargetNamespace $entry.Namespace
                Set-TextAtomic -Path $state.InstalledPath -Content $adaptedContent
                $entry.SourceHash = Get-FileTextHash -Path $state.SourcePath
                $entry.InstalledHash = Get-FileTextHash -Path $state.InstalledPath
                Save-Registry -PlanPath $planFullPath -Registry $registry -Entries $registry.Entries
            }
            catch {
                Set-BytesAtomic -Path $state.InstalledPath -Bytes $oldBytes
                $entry.SourceHash = $oldSourceHash
                $entry.InstalledHash = $oldInstalledHash
                throw
            }
            [pscustomobject]@{ TemplateId = $entry.TemplateId; Status = 'Updated'; Mode = $entry.Mode }
        }
        { $_ -in @('CustomizedWithUpstreamChange', 'ManualUpstreamChange') } {
            $candidatePath = Write-LatestCandidate -Entry $entry -State $state
            [pscustomobject]@{
                TemplateId = $entry.TemplateId
                Status = $state.Status
                Mode = $entry.Mode
                CandidatePath = $candidatePath
                InstalledPath = $state.InstalledPath
            }
            Write-Warning (
                "$($entry.TemplateId): Crow and/or a manual copy changed. Compare '$candidatePath' with " +
                "'$($state.InstalledPath)'; then use Resolve with Replace, Merge, or Retain.")
            $actionRequired = $true
        }
        default {
            [pscustomobject]@{ TemplateId = $entry.TemplateId; Status = $state.Status; Mode = $entry.Mode }
            Write-Warning "$($entry.TemplateId): $($state.Status); user action is required."
            $actionRequired = $true
        }
    }
}

if ($actionRequired) {
    exit 3
}
