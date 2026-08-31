[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path,
    [int]$MaxAgentBytes = 45000,
    [int]$MaxSkillBytes = 20000,
    [int]$MaxModuleBytes = 30000,
    [switch]$StrictContext
)

$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

function Add-ValidationError {
    param([string]$Message)
    $errors.Add($Message)
}

function Add-ValidationWarning {
    param([string]$Message)
    $warnings.Add($Message)
}

function Get-NormalizedContextBytes {
    param([System.IO.FileInfo]$File)

    $content = [System.IO.File]::ReadAllText($File.FullName)
    $normalized = $content.Replace("`r`n", "`n").Replace("`r", "`n")
    return [System.Text.Encoding]::UTF8.GetByteCount($normalized)
}

function Get-Frontmatter {
    param([System.IO.FileInfo]$File)

    $lines = [System.IO.File]::ReadAllLines($File.FullName)
    if ($lines.Count -lt 3 -or $lines[0].Trim() -ne '---') {
        Add-ValidationError "$($File.FullName): missing YAML frontmatter."
        return $null
    }

    $end = -1
    for ($index = 1; $index -lt $lines.Count; $index++) {
        if ($lines[$index].Trim() -eq '---') {
            $end = $index
            break
        }
    }

    if ($end -lt 0) {
        Add-ValidationError "$($File.FullName): YAML frontmatter is not closed."
        return $null
    }

    $values = @{}
    for ($index = 1; $index -lt $end; $index++) {
        if ($lines[$index] -match '^\s*([A-Za-z][A-Za-z0-9_-]*):\s*(.*?)\s*$') {
            $value = $Matches[2].Trim()
            if (($value.StartsWith("'") -and $value.EndsWith("'")) -or
                ($value.StartsWith('"') -and $value.EndsWith('"'))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            $values[$Matches[1]] = $value
        }
    }

    return $values
}

function Get-LocalMarkdownTargets {
    param([System.IO.FileInfo]$File)

    $content = [System.IO.File]::ReadAllText($File.FullName)
    foreach ($match in [regex]::Matches($content, '\[[^\]]+\]\(([^)]+)\)')) {
        $target = $match.Groups[1].Value.Trim().Trim('<', '>')
        if ([string]::IsNullOrWhiteSpace($target) -or
            $target.StartsWith('#') -or
            $target -match '^[A-Za-z][A-Za-z0-9+.-]*:' -or
            $target -match '[\[\]]' -or
            $target.Contains('{{')) {
            continue
        }

        $target = ($target -split '#', 2)[0]
        $target = ($target -split '\s+"', 2)[0]
        if (-not [string]::IsNullOrWhiteSpace($target)) {
            $target
        }
    }
}

$root = (Resolve-Path $RepoRoot).Path
$apmPath = Join-Path $root 'apm.yml'
$pluginPath = Join-Path $root '.github\plugin\plugin.json'
$agentsPath = Join-Path $root '.apm\agents'
$skillsPath = Join-Path $root '.apm\skills'

foreach ($requiredPath in @($apmPath, $pluginPath, $agentsPath, $skillsPath)) {
    if (-not (Test-Path $requiredPath)) {
        Add-ValidationError "Required path is missing: $requiredPath"
    }
}

if ($errors.Count -eq 0) {
    $apmContent = [System.IO.File]::ReadAllText($apmPath)
    if ($apmContent -notmatch '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$') {
        Add-ValidationError 'apm.yml does not contain a valid semantic version.'
    }
    else {
        $apmVersion = $Matches[1]
    }
    if ($apmContent -match '(?m)^includes:\s*auto\s*$') {
        Add-ValidationError "apm.yml must use an explicit publication allowlist; includes: auto can package ignored evidence."
    }
    $includeMatches = [regex]::Matches(
        $apmContent,
        '(?m)^\s{2}-\s+(\.apm/[^\s#]+)\s*$')
    $includePaths = @($includeMatches | ForEach-Object {
        $_.Groups[1].Value.TrimEnd('/').Replace('\', '/')
    })
    if ($includePaths.Count -eq 0) {
        Add-ValidationError 'apm.yml does not contain explicit .apm publication paths.'
    }
    else {
        $apmSourcePath = Join-Path $root '.apm'
        $sourceFiles = @(Get-ChildItem $apmSourcePath -File -Recurse -Force)
        foreach ($sourceFile in $sourceFiles) {
            $relativePath = $sourceFile.FullName.Substring($root.Length + 1)
            $normalizedPath = $relativePath.Replace('\', '/')
            $isEvidence = $normalizedPath -match '(^|/)(evidence|research|transcripts?)(/|\.|$)'
            $isIncluded = @($includePaths | Where-Object {
                $normalizedPath -eq $_ -or
                    $normalizedPath.StartsWith("$_/", [System.StringComparison]::OrdinalIgnoreCase)
            }).Count -gt 0

            if ($isEvidence) {
                Add-ValidationError "Creation evidence must remain outside .apm: $relativePath"
            }
            elseif (-not $isEvidence -and -not $isIncluded) {
                Add-ValidationError "Publication allowlist omits Crow source asset: $relativePath"
            }
        }
    }

    try {
        $plugin = [System.IO.File]::ReadAllText($pluginPath) | ConvertFrom-Json
    }
    catch {
        Add-ValidationError "plugin.json is invalid JSON: $($_.Exception.Message)"
    }

    if ($null -ne $plugin -and $null -ne $apmVersion -and $plugin.version -ne $apmVersion) {
        Add-ValidationError "Version mismatch: apm.yml is $apmVersion and plugin.json is $($plugin.version)."
    }
    if ($null -ne $apmVersion) {
        $readmePath = Join-Path $root 'README.md'
        $readmeContent = [System.IO.File]::ReadAllText($readmePath)
        $readmeVersionMatches = @(
            [regex]::Matches(
                $readmeContent,
                'bcgov/crow#v(?<version>[0-9]+\.[0-9]+\.[0-9]+)'),
            [regex]::Matches(
                $readmeContent,
                'bcgov-crow-(?<version>[0-9]+\.[0-9]+\.[0-9]+)')
        )
        $readmeVersions = @($readmeVersionMatches | ForEach-Object {
            $_ | ForEach-Object { $_.Groups['version'].Value }
        })
        if ($readmeVersions.Count -eq 0) {
            Add-ValidationError 'README.md does not contain Crow installation or archive version examples.'
        }
        foreach ($readmeVersion in $readmeVersions) {
            if ($readmeVersion -ne $apmVersion) {
                Add-ValidationError "Version mismatch: apm.yml is $apmVersion and README.md references $readmeVersion."
            }
        }
    }

    $agentFiles = @(Get-ChildItem $agentsPath -File -Filter '*.agent.md' | Sort-Object Name)
    $skillFiles = @(Get-ChildItem $skillsPath -File -Filter 'SKILL.md' -Recurse | Sort-Object FullName)
    $names = @{}

    foreach ($agentFile in $agentFiles) {
        $frontmatter = Get-Frontmatter $agentFile
        if ($null -eq $frontmatter) {
            continue
        }
        if ([string]::IsNullOrWhiteSpace($frontmatter.name) -or
            -not $frontmatter.name.StartsWith('Crow ')) {
            Add-ValidationError "$($agentFile.FullName): agent name must start with 'Crow '."
        }
        if ([string]::IsNullOrWhiteSpace($frontmatter.description)) {
            Add-ValidationError "$($agentFile.FullName): description is required."
        }
        if (-not $frontmatter.ContainsKey('tools')) {
            Add-ValidationError "$($agentFile.FullName): tools are required."
        }
        $agentContent = [System.IO.File]::ReadAllText($agentFile.FullName)
        if ($agentContent -notmatch '(?im)^##\s+(Core Principles|Non-negotiable principles)\s*$') {
            Add-ValidationError "$($agentFile.FullName): a Core Principles section is required."
        }
        if ($names.ContainsKey($frontmatter.name)) {
            Add-ValidationError "Duplicate asset name '$($frontmatter.name)'."
        }
        else {
            $names[$frontmatter.name] = $agentFile.FullName
        }
        $contextBytes = Get-NormalizedContextBytes $agentFile
        if ($contextBytes -gt $MaxAgentBytes) {
            Add-ValidationWarning "$($agentFile.FullName): $contextBytes normalized UTF-8 bytes exceeds the $MaxAgentBytes-byte agent context threshold."
        }
    }

    $actualSkillPaths = [System.Collections.Generic.List[string]]::new()
    foreach ($skillFile in $skillFiles) {
        $frontmatter = Get-Frontmatter $skillFile
        if ($null -eq $frontmatter) {
            continue
        }

        $folderName = $skillFile.Directory.Name
        if ($frontmatter.name -ne $folderName) {
            Add-ValidationError "$($skillFile.FullName): name '$($frontmatter.name)' must match folder '$folderName'."
        }
        if (-not $folderName.StartsWith('crow-')) {
            Add-ValidationError "$($skillFile.FullName): skill names must start with 'crow-'."
        }
        if ([string]::IsNullOrWhiteSpace($frontmatter.description)) {
            Add-ValidationError "$($skillFile.FullName): description is required."
        }
        if ($names.ContainsKey($frontmatter.name)) {
            Add-ValidationError "Duplicate asset name '$($frontmatter.name)'."
        }
        else {
            $names[$frontmatter.name] = $skillFile.FullName
        }

        $relativeSkillPath = $skillFile.Directory.FullName.Substring($root.Length + 1).Replace('\', '/')
        $actualSkillPaths.Add($relativeSkillPath)
        $contextBytes = Get-NormalizedContextBytes $skillFile
        if ($contextBytes -gt $MaxSkillBytes) {
            Add-ValidationWarning "$($skillFile.FullName): $contextBytes normalized UTF-8 bytes exceeds the $MaxSkillBytes-byte skill-router context threshold."
        }
    }

    if ($null -ne $plugin) {
        $manifestSkillPaths = @($plugin.skills | ForEach-Object { $_.Replace('\', '/') } | Sort-Object)
        $actualSkillPaths = @($actualSkillPaths | Sort-Object)
        $missingFromManifest = @($actualSkillPaths | Where-Object { $_ -notin $manifestSkillPaths })
        $missingFromDisk = @($manifestSkillPaths | Where-Object { $_ -notin $actualSkillPaths })
        foreach ($path in $missingFromManifest) {
            Add-ValidationError "plugin.json is missing skill path '$path'."
        }
        foreach ($path in $missingFromDisk) {
            Add-ValidationError "plugin.json references missing skill path '$path'."
        }
        if ('.apm/agents' -notin @($plugin.agents)) {
            Add-ValidationError "plugin.json must include '.apm/agents'."
        }

        $apmKeywords = @(
            [regex]::Matches($apmContent, '(?m)^\s{2}-\s+(crow-[a-z0-9-]+)\s*$') |
                ForEach-Object { $_.Groups[1].Value } |
                Sort-Object -Unique
        )
        $pluginKeywords = @($plugin.keywords | Sort-Object -Unique)
        foreach ($keyword in @($apmKeywords | Where-Object { $_ -notin $pluginKeywords })) {
            Add-ValidationError "plugin.json keywords are missing '$keyword' from apm.yml."
        }
        foreach ($keyword in @($pluginKeywords | Where-Object { $_ -notin $apmKeywords })) {
            Add-ValidationError "plugin.json keyword '$keyword' is not declared in apm.yml."
        }

        $readmePath = Join-Path $root 'README.md'
        $readmeContent = [System.IO.File]::ReadAllText($readmePath)
        foreach ($skillPath in $actualSkillPaths) {
            $skillName = Split-Path $skillPath -Leaf
            if (-not $readmeContent.Contains("**$skillName**")) {
                Add-ValidationError "README.md does not list skill '$skillName'."
            }
        }
    }

    $moduleFiles = @(Get-ChildItem $skillsPath -File -Filter '*.md' -Recurse |
        Where-Object { $_.FullName -match '[\\/]modules[\\/]' })
    foreach ($moduleFile in $moduleFiles) {
        $contextBytes = Get-NormalizedContextBytes $moduleFile
        if ($contextBytes -gt $MaxModuleBytes) {
            Add-ValidationWarning "$($moduleFile.FullName): $contextBytes normalized UTF-8 bytes exceeds the $MaxModuleBytes-byte module context threshold."
        }
    }

    $markdownFiles = @(
        Get-ChildItem $agentsPath, $skillsPath -File -Filter '*.md' -Recurse
        Get-Item (Join-Path $root 'README.md')
    )
    foreach ($markdownFile in $markdownFiles) {
        foreach ($target in Get-LocalMarkdownTargets $markdownFile) {
            $candidate = Join-Path $markdownFile.Directory.FullName $target
            if (-not (Test-Path $candidate)) {
                Add-ValidationError "$($markdownFile.FullName): local Markdown target '$target' does not exist."
            }
        }
    }

    $trackedFiles = @(& git -C $root ls-files)
    if ($LASTEXITCODE -ne 0) {
        Add-ValidationError 'Unable to enumerate tracked files with git.'
    }
    foreach ($trackedFile in $trackedFiles) {
        $normalized = $trackedFile.Replace('\', '/')
        if ($normalized -match '(^|/)(evidence|research|transcripts?)(/|\.|$)') {
            Add-ValidationError "Tracked creation evidence is not public-release safe: $trackedFile"
        }
    }

    $evidenceDirectories = @(
        Get-ChildItem (Join-Path $root '.apm') -Directory -Recurse -Force |
            Where-Object { $_.Name -in @('evidence', 'research', 'transcript', 'transcripts') }
    )
    foreach ($evidenceDirectory in $evidenceDirectories) {
        Add-ValidationError "Creation evidence must remain outside .apm: $($evidenceDirectory.FullName)"
    }

    $architectureAgentPath = Join-Path $agentsPath 'crow-architecture-review.agent.md'
    $architectureTemplatePath = Join-Path $skillsPath 'crow-architecture-review\architecture-template.md'
    if ((Test-Path $architectureAgentPath) -and (Test-Path $architectureTemplatePath)) {
        $architectureAgentContent = [System.IO.File]::ReadAllText($architectureAgentPath)
        $stepHeadings = @(
            [regex]::Matches($architectureAgentContent, '(?m)^###\s+Step\s+([0-9]+):') |
                ForEach-Object { [int]$_.Groups[1].Value }
        )
        foreach ($duplicateStep in @($stepHeadings | Group-Object | Where-Object Count -gt 1)) {
            Add-ValidationError "Architecture agent contains duplicate Step $($duplicateStep.Name) headings."
        }
        foreach ($stepReference in [regex]::Matches($architectureAgentContent, '\bStep\s+([0-9]+)\b')) {
            $stepNumber = [int]$stepReference.Groups[1].Value
            if ($stepNumber -notin $stepHeadings) {
                Add-ValidationError "Architecture agent references missing Step $stepNumber."
            }
        }

        $templateContent = [System.IO.File]::ReadAllText($architectureTemplatePath)
        $templateSections = @(
            [regex]::Matches($templateContent, '(?m)^##\s+([0-9]+)\.') |
                ForEach-Object { [int]$_.Groups[1].Value }
        )
        foreach ($sectionReference in [regex]::Matches($architectureAgentContent, '\bSection\s+([0-9]+)\b')) {
            $sectionNumber = [int]$sectionReference.Groups[1].Value
            if ($sectionNumber -notin $templateSections) {
                Add-ValidationError "Architecture agent references missing template Section $sectionNumber."
            }
        }
    }
}

foreach ($warning in $warnings) {
    Write-Warning $warning
}
foreach ($validationError in $errors) {
    Write-Error $validationError -ErrorAction Continue
}

Write-Host "Crow asset validation: $($errors.Count) error(s), $($warnings.Count) warning(s)."
if ($errors.Count -gt 0 -or ($StrictContext -and $warnings.Count -gt 0)) {
    exit 1
}
exit 0
