[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RepoRoot,

    [ValidateSet('PreWrite', 'PostWrite')]
    [string]$Phase = 'PostWrite'
)

$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()
$root = (Resolve-Path -LiteralPath $RepoRoot).Path
$markdownPath = [System.IO.Path]::GetFullPath((Join-Path $root 'docs\solution-architecture.md'))
$htmlPath = [System.IO.Path]::GetFullPath((Join-Path $root 'docs\solution-architecture.html'))
$jsonPath = [System.IO.Path]::GetFullPath((Join-Path $root 'docs\solution-architecture-data.json'))
$rendererPath = Join-Path $PSScriptRoot 'Render-SolutionArchitecture.ps1'
$rootPrefix = $root.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar) +
    [System.IO.Path]::DirectorySeparatorChar
$comparison = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') {
    [System.StringComparison]::OrdinalIgnoreCase
}
else {
    [System.StringComparison]::Ordinal
}

function Add-ValidationError {
    param([string]$Message)
    $errors.Add($Message)
}

function Get-SectionContent {
    param(
        [string]$Content,
        [int]$Number,
        [string]$Title
    )
    $match = [regex]::Match(
        $Content,
        '(?ms)^##\s+' + $Number + '\.\s+' + [regex]::Escape($Title) +
        '\s*$\r?\n(.*?)(?=^##\s+\d+\.|\z)')
    if (-not $match.Success) {
        return ''
    }
    return $match.Groups[1].Value
}

function Test-HasTableDataRow {
    param([string]$Section)
    $rows = @(
        $Section -split "\r?\n" |
            Where-Object {
                $_ -match '^\s*\|.*\|\s*$' -and
                $_ -notmatch '^\s*\|(?:\s*:?-+:?\s*\|)+\s*$'
            }
    )
    if ($rows.Count -lt 2) {
        return $false
    }
    foreach ($row in ($rows | Select-Object -Skip 1)) {
        $cells = @(
            $row.Trim().Trim('|').Split('|') |
                ForEach-Object { $_.Trim().Trim('`') }
        )
        $meaningfulCells = @(
            $cells |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_) -and
                    $_ -notmatch '^(TBD|TODO|Unknown|Placeholder)$'
                }
        )
        if ($meaningfulCells.Count -ge 2) {
            return $true
        }
    }
    return $false
}

function Test-RequiredDriverRow {
    param(
        [string]$Section,
        [string]$Driver
    )

    $match = [regex]::Match(
        $Section,
        '(?im)^\|\s*' + [regex]::Escape($Driver) + '\s*\|(.+)\|\s*$')
    if (-not $match.Success) {
        return $false
    }

    $cells = @(
        $match.Groups[1].Value.Split('|') |
            ForEach-Object { $_.Trim().Trim('`') }
    )
    if ($cells.Count -lt 4) {
        return $false
    }
    foreach ($cell in $cells[0..3]) {
        if (
            [string]::IsNullOrWhiteSpace($cell) -or
            $cell -match '^(TBD|TODO|Unknown|Placeholder|Must / Should / Could|-|N/A|None|Not provided|\u2014|\u2026)$'
        ) {
            return $false
        }
    }
    return $true
}

foreach ($outputPath in @($markdownPath, $htmlPath, $jsonPath)) {
    if (-not $outputPath.StartsWith($rootPrefix, $comparison)) {
        Add-ValidationError "Solution architecture output resolves outside the repository: $outputPath"
    }
}

foreach ($outputPath in @($markdownPath, $htmlPath, $jsonPath)) {
    $candidate = $outputPath
    while ($candidate.StartsWith($root, $comparison)) {
        if (Test-Path -LiteralPath $candidate) {
            $item = Get-Item -LiteralPath $candidate -Force
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                Add-ValidationError "Solution architecture output traverses a symbolic link or junction: $($item.FullName)"
                break
            }
        }
        if ($candidate -eq $root) {
            break
        }
        $candidate = Split-Path -Parent $candidate
    }
}

if ($Phase -eq 'PostWrite') {
    if (-not (Test-Path -LiteralPath $markdownPath -PathType Leaf)) {
        Add-ValidationError "Expected solution architecture Markdown is missing: $markdownPath"
    }
    else {
        $content = [System.IO.File]::ReadAllText($markdownPath)
        $validationContent = [regex]::Replace(
            $content,
            '(?ms)^```.*?^```\s*',
            '')
        $requiredHeadings = @(
            '1. Decision Summary',
            '2. Scope and Context',
            '3. Evidence, Assumptions, and Interview Record',
            '4. Quality Attributes and Constraints',
            '5. Proposed Architecture',
            '6. Technology Decisions, Defaults, and Fallbacks',
            '7. Identity and Access',
            '8. Data, Integration, and Common Components',
            '9. Deployment and Operations',
            '10. Security, Privacy, Accessibility, and Language',
            '11. Delivery and Evolution',
            '12. Decisions, Risks, and Open Questions',
            '13. Sources and Freshness'
        )
        foreach ($heading in $requiredHeadings) {
            if ($validationContent -notmatch ('(?m)^##\s+' + [regex]::Escape($heading) + '\s*$')) {
                Add-ValidationError "Solution architecture document is missing required section '$heading'."
            }
        }
        if ($validationContent -match '\{\{[^}]+\}\}' -or $validationContent -match '\bYYYY-MM-DD\b') {
            Add-ValidationError 'Solution architecture document contains unresolved template placeholders.'
        }
        if (
            $validationContent -match 'Draft / Decision-ready / Approved / Superseded' -or
            $validationContent -match 'Confirmed / Provisional / Rejected / Blocked' -or
            $validationContent -match 'Decision / Risk / Question'
        ) {
            Add-ValidationError 'Solution architecture document contains unresolved template choices.'
        }
        if ($validationContent -notmatch '(?m)^>\s*Status:\s*`?(Draft|Decision-ready|Approved|Superseded)`?\s*$') {
            Add-ValidationError 'Solution architecture document requires one resolved status.'
        }
        $ownerMatch = [regex]::Match($validationContent, '(?m)^>\s*Owner:\s*(.+?)\s*$')
        if (
            -not $ownerMatch.Success -or
            [string]::IsNullOrWhiteSpace($ownerMatch.Groups[1].Value.Trim('`', ' ')) -or
            $ownerMatch.Groups[1].Value -match '\{\{'
        ) {
            Add-ValidationError 'Solution architecture document requires an accountable owner.'
        }
        if ($validationContent -notmatch '(?m)^>\s*Last reviewed:\s*`?[0-9]{4}-[0-9]{2}-[0-9]{2}`?\s*$') {
            Add-ValidationError 'Solution architecture document requires a last-reviewed date.'
        }
        if ($content -match '<!--') {
            Add-ValidationError 'Solution architecture document contains unresolved template instructions.'
        }
        if ($content -notmatch '(?ms)```mermaid\s+(graph|flowchart|sequenceDiagram)\b.+?```') {
            Add-ValidationError 'Solution architecture document requires a populated Mermaid diagram.'
        }
        $requiredTableSections = @(
            @{ Number = 2; Title = 'Scope and Context'; Name = 'representative UX example' },
            @{ Number = 3; Title = 'Evidence, Assumptions, and Interview Record'; Name = 'evidence or interview record' },
            @{ Number = 4; Title = 'Quality Attributes and Constraints'; Name = 'quality attribute or constraint' },
            @{ Number = 5; Title = 'Proposed Architecture'; Name = 'workflow or data flow' },
            @{ Number = 6; Title = 'Technology Decisions, Defaults, and Fallbacks'; Name = 'technology decision and fallback' },
            @{ Number = 7; Title = 'Identity and Access'; Name = 'identity and authorization decision' },
            @{ Number = 8; Title = 'Data, Integration, and Common Components'; Name = 'reuse, integration, or common-component decision' },
            @{ Number = 12; Title = 'Decisions, Risks, and Open Questions'; Name = 'decision, risk, or open question' }
        )
        foreach ($sectionRule in $requiredTableSections) {
            $section = Get-SectionContent $validationContent $sectionRule.Number $sectionRule.Title
            if (-not (Test-HasTableDataRow $section)) {
                Add-ValidationError "Solution architecture document requires at least one populated $($sectionRule.Name) row."
            }
        }
        $qualitySection = Get-SectionContent $validationContent 4 'Quality Attributes and Constraints'
        foreach ($requiredDriver in @(
            'Business criticality',
            'Uptime',
            'Recovery time objective (RTO)',
            'Recovery point objective (RPO)',
            'Data classification',
            'Data retention and destruction'
        )) {
            if (-not (Test-RequiredDriverRow $qualitySection $requiredDriver)) {
                Add-ValidationError "Solution architecture quality attributes require a populated '$requiredDriver' row."
            }
        }
        $sourceSection = [regex]::Match(
            $validationContent,
            '(?ms)^##\s+13\.\s+Sources and Freshness\s*$\r?\n(.*?)(?=^##\s+|\z)')
        if (
            -not $sourceSection.Success -or
            $sourceSection.Groups[1].Value -notmatch '(?m)^\|[^|\r\n]+\|[^|\r\n]+\|[^|\r\n]+\|\s*`?[0-9]{4}-[0-9]{2}-[0-9]{2}`?\s*\|[^|\r\n]+\|\s*$'
        ) {
            Add-ValidationError 'Solution architecture document requires at least one dated source row.'
        }
        foreach ($proseSection in @(
            @{ Number = 1; Title = 'Decision Summary' },
            @{ Number = 9; Title = 'Deployment and Operations' },
            @{ Number = 10; Title = 'Security, Privacy, Accessibility, and Language' },
            @{ Number = 11; Title = 'Delivery and Evolution' }
        )) {
            $section = Get-SectionContent $validationContent $proseSection.Number $proseSection.Title
            $plainText = ($section -replace '(?m)^\s*[|:#>-].*$', '').Trim()
            if (
                $plainText.Length -lt 40 -or
                $plainText -match '(?i)\b(TBD|TODO|to be determined|placeholder|add content)\b'
            ) {
                Add-ValidationError "Solution architecture section '$($proseSection.Number). $($proseSection.Title)' requires substantive content."
            }
        }
    }

    if (-not (Test-Path -LiteralPath $htmlPath -PathType Leaf)) {
        Add-ValidationError "Expected solution architecture HTML is missing: $htmlPath"
    }
    elseif (Test-Path -LiteralPath $markdownPath -PathType Leaf) {
        $html = [System.IO.File]::ReadAllText($htmlPath)
        $markdownBytes = [System.IO.File]::ReadAllBytes($markdownPath)
        $sourceHash = [System.BitConverter]::ToString(
            [System.Security.Cryptography.SHA256]::Create().ComputeHash($markdownBytes)
        ).Replace('-', '').ToLowerInvariant()

        if ($html -match '\{\{[^}]+\}\}') {
            Add-ValidationError 'Solution architecture HTML contains unresolved template placeholders.'
        }
        if ($html -notmatch '(?is)<meta\s+name=["'']crow-source-sha256["'']\s+content=["'']([^"'']+)["'']') {
            Add-ValidationError 'Solution architecture HTML is missing the crow-source-sha256 meta element.'
        }
        elseif ($Matches[1] -ne $sourceHash) {
            Add-ValidationError 'Solution architecture HTML is stale relative to the canonical Markdown.'
        }
        foreach ($element in @('header', 'nav', 'main', 'section', 'table')) {
            if ($html -notmatch ('(?is)<' + $element + '\b')) {
                Add-ValidationError "Solution architecture HTML is missing semantic <$element> content."
            }
        }
        if ($html -match '(?is)<(script|link|img)\b[^>]+(?:src|href)=["'']https?://') {
            Add-ValidationError 'Solution architecture HTML must not depend on remote scripts, styles, or images.'
        }
        if ($html -notmatch '(?is)<figure\s+class=["'']flow-view["''].*?<ol\s+class=["'']flow-list["''].*?<li>') {
            Add-ValidationError 'Solution architecture HTML requires a semantic architecture flow view.'
        }

        try {
            & $rendererPath -RepoRoot $root -MarkdownPath $markdownPath `
                -OutputPath $htmlPath -Check
        }
        catch {
            Add-ValidationError "Unable to verify rendered solution architecture HTML: $($_.Exception.Message)"
        }
    }

    if (Test-Path -LiteralPath $jsonPath -PathType Leaf) {
        try {
            $json = [System.IO.File]::ReadAllText($jsonPath) | ConvertFrom-Json
            if (-not $json.sourceSha256) {
                Add-ValidationError 'Optional solution architecture JSON is missing sourceSha256.'
            }
            elseif (Test-Path -LiteralPath $markdownPath -PathType Leaf) {
                $markdownBytes = [System.IO.File]::ReadAllBytes($markdownPath)
                $sourceHash = [System.BitConverter]::ToString(
                    [System.Security.Cryptography.SHA256]::Create().ComputeHash($markdownBytes)
                ).Replace('-', '').ToLowerInvariant()
                if ($json.sourceSha256 -ne $sourceHash) {
                    Add-ValidationError 'Optional solution architecture JSON is stale relative to the canonical Markdown.'
                }
            }
            & $rendererPath -RepoRoot $root -MarkdownPath $markdownPath `
                -OutputPath $htmlPath -JsonOutputPath $jsonPath -Check
        }
        catch {
            Add-ValidationError "Optional solution architecture JSON is invalid: $($_.Exception.Message)"
        }
    }
}

foreach ($validationError in $errors) {
    Write-Error $validationError -ErrorAction Continue
}

Write-Host "Solution architecture output validation: $($errors.Count) error(s)."
if ($errors.Count -gt 0) {
    exit 1
}
exit 0
