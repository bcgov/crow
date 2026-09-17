[CmdletBinding()]
param(
    [string]$SkillRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
)

$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()
$referenceRoot = Join-Path $SkillRoot 'references'
$decisionRoot = Join-Path $SkillRoot 'decisions'

$expectedReferences = @(
    'cloud-migration-portability.md',
    'data-classification.md',
    'dax-studio-workflow.md',
    'dax-style-guide.md',
    'devops-deployment-patterns.md',
    'devops-operations-patterns.md',
    'documentation-authoring.md',
    'dw-calendar-build.md',
    'dw-physical-design.md',
    'dw-review-checklist.md',
    'dw-validation-patterns.md',
    'elt-patterns.md',
    'extended-properties-templates.md',
    'kimball-advanced-patterns.md',
    'kimball-patterns.md',
    'pbirs-constraints.md',
    'pbix-report-standards.md',
    'performance-end-to-end.md',
    'security-implementation.md',
    'source-system-analysis.md',
    'sqlbi-dax-patterns-advanced.md',
    'sqlbi-dax-patterns-niche.md',
    'sqlbi-dax-patterns.md',
    'ssas-deployment-processing.md',
    'ssas-tabular-bp.md',
    'ssdt-project-structure.md',
    'ssisdb-catalog-config.md',
    'tabular-editor-2-automation.md'
)

foreach ($name in $expectedReferences) {
    $path = Join-Path $referenceRoot $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $errors.Add("Missing reference: $name")
    }
}

$actualReferences = @(Get-ChildItem -LiteralPath $referenceRoot -File -Filter '*.md' |
    ForEach-Object Name | Sort-Object)
$missing = @($expectedReferences | Where-Object { $_ -notin $actualReferences })
$unexpected = @($actualReferences | Where-Object { $_ -notin $expectedReferences })
if ($missing.Count -gt 0) {
    $errors.Add("Expected references missing from directory: $($missing -join ', ')")
}
if ($unexpected.Count -gt 0) {
    $errors.Add("Unexpected Markdown references in directory: $($unexpected -join ', ')")
}
foreach ($decision in @('org-design-constraints.md', 'decision-map.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $decisionRoot $decision) -PathType Leaf)) {
        $errors.Add("Missing decision file: $decision")
    }
}

$consumerSkills = @(
    (Join-Path $RepositoryRoot '.apm\skills\crow-db-documentation\SKILL.md'),
    (Join-Path $RepositoryRoot '.apm\skills\crow-report-designer\SKILL.md'),
    (Join-Path $RepositoryRoot '.apm\skills\crow-ssas-tabular-dw-architect\SKILL.md')
)
$consumerText = ($consumerSkills | ForEach-Object {
    if (-not (Test-Path -LiteralPath $_ -PathType Leaf)) {
        $errors.Add("Missing consumer skill: $_")
        return
    }
    [System.IO.File]::ReadAllText($_)
}) -join "`n"

$unsafePatterns = @(
    'C:\Projects',
    'ISBDevOps',
    'C:\Reports',
    'C:\Program Files',
    'C:\...',
    'D:\SQLData',
    'E:\SQLArchive'
)
foreach ($file in Get-ChildItem -LiteralPath $referenceRoot -File -Filter '*.md') {
    $text = [System.IO.File]::ReadAllText($file.FullName)
    if ($text.Contains([string][char]0xFFFD)) {
        $errors.Add("$($file.Name) contains a Unicode replacement character.")
    }
    if ($text.Contains([char]0x00E2) -or $text.Contains([char]0x00C3) -or $text.Contains([char]0x00C2)) {
        $errors.Add("$($file.Name) contains probable mojibake.")
    }
    foreach ($pattern in $unsafePatterns) {
        if ($text -match [regex]::Escape($pattern)) {
            $errors.Add("$($file.Name) contains non-portable path pattern: $pattern")
        }
    }
}

if (-not $consumerText.Contains("reference-index.md")) {
    $errors.Add("At least one consumer does not route through reference-index.md.")
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "DW/SSAS reference validation: $($actualReferences.Count) references, 0 errors."
