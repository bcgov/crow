[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RepoRoot,

    [Parameter(Mandatory)]
    [ValidateSet('SingleApp', 'Monorepo')]
    [string]$Classification,

    [string]$ServiceInventoryPath,

    [ValidateSet('PreWrite', 'PostWrite')]
    [string]$Phase = 'PostWrite'
)

$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()
$root = (Resolve-Path $RepoRoot).Path
$docsPath = Join-Path $root 'docs'
$rootArchitecturePath = Join-Path $docsPath 'architecture.md'
$outputPaths = [System.Collections.Generic.List[string]]::new()

function Add-ValidationError {
    param([string]$Message)
    $errors.Add($Message)
}

function Test-NoReparsePoint {
    param(
        [string]$Path,
        [string]$Description
    )

    $candidate = $Path
    while (-not [string]::IsNullOrWhiteSpace($candidate)) {
        if (Test-Path -LiteralPath $candidate) {
            $item = Get-Item -LiteralPath $candidate -Force
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                Add-ValidationError "$Description traverses a symbolic link or junction: $($item.FullName)"
                return $false
            }
        }
        if ($candidate -eq $root) {
            break
        }
        $parent = Split-Path -Parent $candidate
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent.Length -ge $candidate.Length) {
            break
        }
        $candidate = $parent
    }

    return $true
}

function Resolve-RepositoryPath {
    param(
        [string]$RelativePath,
        [string]$Description,
        [switch]$RequireFile,
        [switch]$AllowMissing
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath) -or [System.IO.Path]::IsPathRooted($RelativePath)) {
        Add-ValidationError "$Description must be a repository-relative path: $RelativePath"
        return $null
    }

    $resolved = [System.IO.Path]::GetFullPath((Join-Path $root $RelativePath))
    $rootPrefix = $root.TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        Add-ValidationError "$Description resolves outside the repository: $RelativePath"
        return $null
    }
    if (-not (Test-NoReparsePoint $resolved $Description)) {
        return $null
    }
    if (-not $AllowMissing -and $RequireFile -and -not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        Add-ValidationError "$Description does not exist: $RelativePath"
    }
    elseif (-not $AllowMissing -and -not $RequireFile -and -not (Test-Path -LiteralPath $resolved -PathType Container)) {
        Add-ValidationError "$Description does not exist: $RelativePath"
    }

    return $resolved
}

function Test-DocumentContent {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-ValidationError "Expected architecture document is missing: $Path"
        return
    }

    $content = [System.IO.File]::ReadAllText($Path)
    $templatePath = Join-Path $PSScriptRoot '..\architecture-template.md'
    $templateContent = [System.IO.File]::ReadAllText((Resolve-Path $templatePath).Path)
    $requiredHeadings = @(
        [regex]::Matches($templateContent, '(?m)^##\s+([0-9]+\.\s+.+?)\s*$') |
            ForEach-Object { $_.Groups[1].Value }
    )
    if ($content -notmatch '(?m)^##\s+Revision History\s*$') {
        Add-ValidationError "Architecture document is missing the Revision History section: $Path"
    }
    foreach ($requiredHeading in $requiredHeadings) {
        if ($content -notmatch ('(?m)^##\s+' + [regex]::Escape($requiredHeading) + '\s*$')) {
            Add-ValidationError "Architecture document is missing required section '$requiredHeading': $Path"
        }
    }

    $requiredTableHeaders = @(
        [regex]::Matches($templateContent, '(?m)^(?<header>\|[^\r\n]+\|)\r?\n\|\s*:?-') |
            ForEach-Object { $_.Groups['header'].Value }
    )
    foreach ($requiredTableHeader in $requiredTableHeaders) {
        if ($content -notmatch ('(?m)^' + [regex]::Escape($requiredTableHeader) + '\s*$')) {
            Add-ValidationError "Architecture document is missing required table '$requiredTableHeader': $Path"
        }
    }

    $sectionMatches = [regex]::Matches($content, '(?m)^##\s+.+$')
    for ($sectionIndex = 0; $sectionIndex -lt $sectionMatches.Count; $sectionIndex++) {
        $bodyStart = $sectionMatches[$sectionIndex].Index + $sectionMatches[$sectionIndex].Length
        $bodyEnd = if ($sectionIndex + 1 -lt $sectionMatches.Count) {
            $sectionMatches[$sectionIndex + 1].Index
        }
        else {
            $content.Length
        }
        $sectionBody = $content.Substring($bodyStart, $bodyEnd - $bodyStart)
        $substantiveBody = [regex]::Replace($sectionBody, '(?m)^(#{3,}|---)\s*.*$', '').Trim()
        if ($substantiveBody.Length -lt 10) {
            Add-ValidationError "Architecture section has no substantive content '$($sectionMatches[$sectionIndex].Value)': $Path"
        }
    }

    if ($content -notmatch '(?m)^\|\s*`?[0-9]+\.[0-9]+`?\s*\|\s*`?[0-9]{4}-[0-9]{2}-[0-9]{2}`?\s*\|') {
        Add-ValidationError "Architecture document is missing a dated revision-history row: $Path"
    }
    if ($content -notmatch '(?m)^\|.+\|.+\|') {
        Add-ValidationError "Architecture document does not contain a Markdown table: $Path"
    }
    $requiredDiagramCount = [regex]::Matches($templateContent, '(?ms)```mermaid\s+.+?```').Count
    $diagramCount = [regex]::Matches($content, '(?ms)```mermaid\s+(graph|flowchart|sequenceDiagram)\b.+?```').Count
    if ($diagramCount -lt $requiredDiagramCount) {
        Add-ValidationError "Architecture document contains $diagramCount populated Mermaid diagram(s); expected at least $requiredDiagramCount`: $Path"
    }
    if ($content -match '\{\{[^}]+\}\}') {
        Add-ValidationError "Architecture document contains an unresolved template placeholder: $Path"
    }
    if ($content -match '\[Confidence:\s*\]') {
        Add-ValidationError "Architecture document contains an empty confidence annotation: $Path"
    }
    if ($content -match '\bYYYY-MM-DD\b') {
        Add-ValidationError "Architecture document contains an unresolved revision date: $Path"
    }
    $templateInstructions = @(
        [regex]::Matches(
            $templateContent,
            '\*(?<instruction>(Provide|Describe|Document|Identify|List|Use|Reference)\b[^*]+)\*') |
            ForEach-Object { $_.Value }
    )
    foreach ($templateInstruction in $templateInstructions) {
        if ($content.Contains($templateInstruction)) {
            Add-ValidationError "Architecture document contains unresolved template instruction '$templateInstruction': $Path"
        }
    }
    if ($content.Contains('# Represent the key boundaries / packages using a relative file-tree layout')) {
        Add-ValidationError "Architecture document contains the example file-tree instruction: $Path"
    }
    if ($content.Contains('`[Name]`')) {
        Add-ValidationError "Architecture document contains the unresolved cluster-name placeholder: $Path"
    }

    $templateOptions = @(
        [regex]::Matches($templateContent, '`[^`\r\n]+ / [^`\r\n]+`') |
            ForEach-Object { $_.Value } |
            Sort-Object -Unique
    )
    foreach ($templateOption in $templateOptions) {
        if ($content.Contains($templateOption)) {
            Add-ValidationError "Architecture document contains unresolved option list '$templateOption': $Path"
        }
    }

    foreach ($tableLine in @($content -split '\r?\n' | Where-Object { $_ -match '^\|.+\|$' })) {
        $cells = @($tableLine.Trim('|').Split('|'))
        if (@($cells | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
            Add-ValidationError "Architecture document contains an empty table cell in '$tableLine': $Path"
        }
    }

    foreach ($confidenceMatch in [regex]::Matches($content, '\[Confidence:\s*([^\]]*)\]')) {
        $confidence = $confidenceMatch.Groups[1].Value.Trim()
        if ($confidence -notin @('Verified', 'Inferred', 'Unknown', 'N/A')) {
            Add-ValidationError "Architecture document contains unsupported confidence '$($confidenceMatch.Groups[1].Value)': $Path"
        }
    }

    $checklistLabels = @(
        [regex]::Matches($templateContent, '(?m)^- \[ \] \*\*([^:]+):\*\*') |
            ForEach-Object { $_.Groups[1].Value }
    )
    foreach ($label in $checklistLabels) {
        $pattern = '(?m)^- \[(?<checked> |x|X)\] \*\*' + [regex]::Escape($label) +
            ':\*\*.+`?\[Confidence:\s*(?<confidence>Verified|Inferred|Unknown|N/A)\s*\]`?\s*$'
        $checklistMatch = [regex]::Match($content, $pattern)
        if (-not $checklistMatch.Success) {
            Add-ValidationError "Architecture document is missing a completed '$label' checklist entry: $Path"
            continue
        }
        $isChecked = $checklistMatch.Groups['checked'].Value -ne ' '
        $isVerified = $checklistMatch.Groups['confidence'].Value -eq 'Verified'
        if ($isChecked -ne $isVerified) {
            Add-ValidationError "Checklist entry '$label' must be checked if and only if confidence is Verified: $Path"
        }
    }
}

if ($Classification -eq 'SingleApp') {
    if (-not [string]::IsNullOrWhiteSpace($ServiceInventoryPath)) {
        Add-ValidationError 'ServiceInventoryPath is valid only for Monorepo classification.'
    }
    if (Test-NoReparsePoint $rootArchitecturePath 'Single-application output path') {
        $outputPaths.Add($rootArchitecturePath)
    }
}
else {
    if ([string]::IsNullOrWhiteSpace($ServiceInventoryPath)) {
        Add-ValidationError 'Monorepo validation requires ServiceInventoryPath.'
    }
    elseif (-not (Test-Path -LiteralPath $ServiceInventoryPath -PathType Leaf)) {
        Add-ValidationError "Service inventory does not exist: $ServiceInventoryPath"
    }
    else {
        try {
            $inventory = @([System.IO.File]::ReadAllText((Resolve-Path $ServiceInventoryPath).Path) | ConvertFrom-Json)
        }
        catch {
            Add-ValidationError "Service inventory is invalid JSON: $($_.Exception.Message)"
            $inventory = @()
        }

        if ($inventory.Count -eq 0) {
            Add-ValidationError 'Service inventory must contain at least one service.'
        }

        $names = @{}
        $paths = @{}
        foreach ($service in $inventory) {
            foreach ($property in @('name', 'sourcePath', 'manifestPath', 'deploymentEntryPoint', 'outputPath')) {
                if ([string]::IsNullOrWhiteSpace([string]$service.$property)) {
                    Add-ValidationError "Service inventory entry is missing '$property'."
                }
            }

            $name = [string]$service.name
            $normalizedOutput = ([string]$service.outputPath).Replace('\', '/').TrimStart('/')
            if ($name -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
                Add-ValidationError "Service name contains unsupported path characters: $name"
            }
            if (-not [string]::IsNullOrWhiteSpace($name)) {
                if ($names.ContainsKey($name)) {
                    Add-ValidationError "Duplicate service name: $name"
                }
                $names[$name] = $true
            }
            if ($normalizedOutput -notmatch '^docs/[^/]+/architecture\.md$') {
                Add-ValidationError "Invalid service output path '$normalizedOutput'. Expected docs/<service-name>/architecture.md."
            }
            elseif ($normalizedOutput -ne "docs/$name/architecture.md") {
                Add-ValidationError "Service '$name' output path must be docs/$name/architecture.md."
            }
            if ($paths.ContainsKey($normalizedOutput)) {
                Add-ValidationError "Duplicate service output path: $normalizedOutput"
            }
            $paths[$normalizedOutput] = $true
            $resolvedOutput = Resolve-RepositoryPath $normalizedOutput "Service '$name' output path" -RequireFile -AllowMissing:($Phase -eq 'PreWrite')
            if ($null -ne $resolvedOutput) {
                $outputPaths.Add($resolvedOutput)
            }

            Resolve-RepositoryPath ([string]$service.sourcePath) "Service '$name' source path" | Out-Null
            Resolve-RepositoryPath ([string]$service.manifestPath) "Service '$name' manifest path" -RequireFile | Out-Null
            Resolve-RepositoryPath ([string]$service.deploymentEntryPoint) "Service '$name' deployment entry point" -RequireFile | Out-Null
        }

        if ($Phase -eq 'PostWrite') {
            $actualServiceDocuments = @(
                Get-ChildItem -Path $docsPath -Filter 'architecture.md' -File -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -ne $rootArchitecturePath } |
                    ForEach-Object { $_.FullName }
            )
            $unexpectedDocuments = @($actualServiceDocuments | Where-Object { $_ -notin $outputPaths })
            foreach ($unexpectedDocument in $unexpectedDocuments) {
                Add-ValidationError "Architecture document is not represented in the service inventory: $unexpectedDocument"
            }
        }
    }

    if (Test-Path -LiteralPath $rootArchitecturePath) {
        Add-ValidationError "Monorepo must not contain root architecture document: $rootArchitecturePath"
    }

    $indexPath = Join-Path $docsPath 'architecture-index.md'
    Test-NoReparsePoint $indexPath 'Monorepo architecture index' | Out-Null
    if ($Phase -eq 'PostWrite' -and -not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
        Add-ValidationError "Monorepo architecture index is missing: $indexPath"
    }
    elseif ($Phase -eq 'PostWrite') {
        $indexContent = [System.IO.File]::ReadAllText($indexPath).Replace('\', '/')
        foreach ($requiredIndexHeading in @('Services', 'Shared Infrastructure', 'Inter-Service Communication')) {
            if ($indexContent -notmatch ('(?m)^##\s+' + [regex]::Escape($requiredIndexHeading) + '\s*$')) {
                Add-ValidationError "Architecture index is missing '$requiredIndexHeading'."
            }
        }
        if ($indexContent -cmatch '\b(SERVICE_NAME|SERVICE_SOURCE_PATH|PRIMARY_TECHNOLOGY|STATUS)\b') {
            Add-ValidationError 'Architecture index contains unresolved template placeholders.'
        }
        $indexWithoutCodeFences = [regex]::Replace(
            $indexContent,
            '(?ms)(?<fence>```|~~~).*?\k<fence>',
            '')
        foreach ($outputPath in $outputPaths) {
            $relativeLink = './' + $outputPath.Substring($docsPath.Length + 1).Replace('\', '/')
            $linkPattern = '\[[^\]]+\]\(' + [regex]::Escape($relativeLink) + '(?:\s+"[^"]*")?\)'
            if ($indexWithoutCodeFences -notmatch $linkPattern) {
                Add-ValidationError "Architecture index does not link '$relativeLink'."
            }
        }
    }
}

if ($Phase -eq 'PostWrite') {
    foreach ($outputPath in $outputPaths) {
        Test-DocumentContent $outputPath
    }
}

foreach ($validationError in $errors) {
    Write-Error $validationError -ErrorAction Continue
}

Write-Host "Architecture output validation: $($errors.Count) error(s)."
if ($errors.Count -gt 0) {
    exit 1
}
exit 0
