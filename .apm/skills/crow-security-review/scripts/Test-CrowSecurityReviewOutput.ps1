[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ReportPath,

    [Parameter(Mandatory)]
    [string]$SynthesisPath
)

$ErrorActionPreference = 'Stop'
$errors = [System.Collections.Generic.List[string]]::new()

function Add-ValidationError {
    param([string]$Message)
    $errors.Add($Message)
}

function Get-FrontmatterValue {
    param(
        [string]$Frontmatter,
        [string]$Name
    )

    $match = [regex]::Match(
        $Frontmatter,
        '(?m)^' + [regex]::Escape($Name) + ':\s*(.*?)\s*$')
    if (-not $match.Success) {
        Add-ValidationError "Security report frontmatter is missing '$Name'."
        return $null
    }
    return $match.Groups[1].Value.Trim().Trim('"', "'")
}

function Get-NumberText {
    param([object]$Value)

    return [string]::Format(
        [System.Globalization.CultureInfo]::InvariantCulture,
        '{0:0.##}',
        [double]$Value)
}

if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
    Add-ValidationError "Security report does not exist: $ReportPath"
}
if (-not (Test-Path -LiteralPath $SynthesisPath -PathType Leaf)) {
    Add-ValidationError "Security synthesis does not exist: $SynthesisPath"
}

if ($errors.Count -eq 0) {
    try {
        $report = [System.IO.File]::ReadAllText((Resolve-Path $ReportPath).Path)
        $synthesis = [System.IO.File]::ReadAllText(
            (Resolve-Path $SynthesisPath).Path) | ConvertFrom-Json
    }
    catch {
        Add-ValidationError "Unable to read report inputs: $($_.Exception.Message)"
    }
}

if ($errors.Count -eq 0) {
    $frontmatterMatch = [regex]::Match(
        $report,
        '\A---\s*\r?\n(?<content>.*?)\r?\n---\s*\r?\n',
        [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $frontmatterMatch.Success) {
        Add-ValidationError 'Security report is missing YAML frontmatter.'
    }
    else {
        $frontmatter = $frontmatterMatch.Groups['content'].Value
        $reportScope = Get-FrontmatterValue $frontmatter 'report_scope'
        $serviceName = Get-FrontmatterValue $frontmatter 'service_name'
        $servicePath = Get-FrontmatterValue $frontmatter 'service_path'
        $synthesisArtifact = Get-FrontmatterValue $frontmatter 'synthesis_artifact'
        if ($reportScope -cne 'SingleApp' -and $reportScope -cne 'Monorepo') {
            Add-ValidationError "Security report frontmatter 'report_scope' must be 'SingleApp' or 'Monorepo'."
        }
        if ([string]::IsNullOrWhiteSpace($serviceName) -or
            $serviceName -cne [string]$synthesis.serviceName) {
            Add-ValidationError "Security report frontmatter 'service_name' must match the synthesis serviceName."
        }
        if ([string]::IsNullOrWhiteSpace($servicePath)) {
            Add-ValidationError "Security report frontmatter 'service_path' cannot be empty."
        }
        elseif ($reportScope -ceq 'SingleApp' -and $servicePath -cne '.') {
            Add-ValidationError "Single-app security report frontmatter 'service_path' must be '.'."
        }
        elseif ($reportScope -ceq 'Monorepo') {
            $servicePathSegments = @($servicePath -split '[\\/]')
            if ($servicePath -match '^(?:[\\/]|[A-Za-z]:)' -or
                $servicePathSegments -contains '' -or
                $servicePathSegments -contains '.' -or
                $servicePathSegments -contains '..') {
                Add-ValidationError "Monorepo security report frontmatter 'service_path' must be a repository-relative service path."
            }
        }

        if ($reportScope -ceq 'SingleApp') {
            $expectedArtifact = 'docs/security-review-synthesis.json'
        }
        elseif ($reportScope -ceq 'Monorepo') {
            if ($serviceName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
                Add-ValidationError "Monorepo security report frontmatter 'service_name' is not a safe service identifier."
            }
            $expectedArtifact = "docs/$serviceName/security-review-synthesis.json"
        }
        else {
            $expectedArtifact = $null
        }
        if ($null -ne $expectedArtifact -and
            $synthesisArtifact -cne $expectedArtifact) {
            Add-ValidationError "Security report frontmatter 'synthesis_artifact' must be '$expectedArtifact'."
        }

        $reportDirectory = Split-Path -Parent $ReportPath
        $reportDirectoryName = [System.IO.Path]::GetFileName($reportDirectory)
        $reportParentDirectoryName = [System.IO.Path]::GetFileName(
            (Split-Path -Parent $reportDirectory))
        $reportLocationIsInvalid = [System.IO.Path]::GetFileName($ReportPath) -cne 'security-review.md'
        if ($reportScope -ceq 'SingleApp' -and $reportDirectoryName -cne 'docs') {
            $reportLocationIsInvalid = $true
        }
        elseif ($reportScope -ceq 'Monorepo' -and
            ($reportDirectoryName -cne $serviceName -or
                $reportParentDirectoryName -cne 'docs')) {
            $reportLocationIsInvalid = $true
        }
        if ($reportLocationIsInvalid) {
            Add-ValidationError "Security report path does not match its '$reportScope' service scope."
        }

        $expectedSynthesisPath = [System.IO.Path]::GetFullPath(
            (Join-Path $reportDirectory 'security-review-synthesis.json'))
        $actualSynthesisPath = [System.IO.Path]::GetFullPath($SynthesisPath)
        if ($actualSynthesisPath -cne $expectedSynthesisPath) {
            Add-ValidationError 'Security synthesis must be adjacent to its report.'
        }

        $countMap = [ordered]@{
            total_findings = 'totalFindings'
            critical_count = 'criticalCount'
            high_count = 'highCount'
            medium_count = 'mediumCount'
            low_count = 'lowCount'
            informational_count = 'informationalCount'
            confirmed_count = 'confirmedCount'
            probable_count = 'probableCount'
            finding_chain_count = 'chainCount'
            unresolved_validation_count = 'unresolvedValidationCount'
        }
        foreach ($entry in $countMap.GetEnumerator()) {
            $actualText = Get-FrontmatterValue $frontmatter $entry.Key
            if ($null -eq $actualText -or $actualText -notmatch '^\d+$') {
                Add-ValidationError "Security report frontmatter '$($entry.Key)' must be an integer."
                continue
            }
            $expected = [int]$synthesis.summary.($entry.Value)
            if ([int]$actualText -ne $expected) {
                Add-ValidationError "Security report frontmatter '$($entry.Key)' is $actualText; expected $expected."
            }
        }

        $priorityModel = Get-FrontmatterValue $frontmatter 'component_priority_model'
        if ($priorityModel -ne [string]$synthesis.priorityModel.name) {
            Add-ValidationError "Security report component_priority_model does not match the synthesis."
        }
        $sourceRevision = Get-FrontmatterValue $frontmatter 'source_revision'
        if ($sourceRevision -ne [string]$synthesis.sourceRevision) {
            Add-ValidationError "Security report source_revision does not match the synthesis."
        }
    }

    foreach ($heading in @(
        'Architecture handoff',
        'Security control assurance',
        'Cross-cutting themes',
        'Evidence-backed attack paths',
        'Component remediation priority',
        'Validation adjudication')) {
        if ($report -notmatch ('(?m)^###\s+' + [regex]::Escape($heading) + '\s*$')) {
            Add-ValidationError "Security report is missing synthesis heading '$heading'."
        }
    }

    foreach ($finding in @($synthesis.findings | Where-Object { $_.active })) {
        if ($report -notmatch ('(?m)' + [regex]::Escape([string]$finding.findingId))) {
            Add-ValidationError "Security report does not reference active finding '$($finding.findingId)'."
        }
    }
    foreach ($theme in @($synthesis.themes)) {
        if ($report -notmatch ('(?m)' + [regex]::Escape([string]$theme.themeId))) {
            Add-ValidationError "Security report does not reference theme '$($theme.themeId)'."
        }
    }
    foreach ($chain in @($synthesis.chains)) {
        if ($report -notmatch ('(?m)' + [regex]::Escape([string]$chain.chainId))) {
            Add-ValidationError "Security report does not reference chain '$($chain.chainId)'."
        }
    }
    $priorityRank = 1
    foreach ($component in @($synthesis.componentPriorities)) {
        $cells = @(
            [string]$priorityRank,
            [string]$component.component,
            [string]$component.exposure,
            [string]$component.activeFindingCount,
            [string]$component.distinctDomainCount,
            (Get-NumberText $component.baseScore),
            (Get-NumberText $component.breadthFactor),
            (Get-NumberText $component.exposureFactor),
            (Get-NumberText $component.priorityScore)
        )
        $priorityPattern = '(?m)^\|\s*' +
            (($cells | ForEach-Object { [regex]::Escape($_) }) -join '\s*\|\s*') +
            '\s*\|\s*$'
        if ($report -notmatch $priorityPattern) {
            Add-ValidationError "Security report does not contain the canonical priority row for component '$($component.component)'."
        }
        $priorityRank++
    }

    foreach ($finding in @(
        $synthesis.findings |
            Where-Object { $_.validationDisposition -ne 'NotReviewed' })) {
        $adjudicationPattern = '(?m)^\|\s*' +
            [regex]::Escape([string]$finding.findingId) +
            '\s*\|\s*' +
            [regex]::Escape([string]$finding.validationDisposition) +
            '\s*\|[^|]*\|\s*' +
            [regex]::Escape([string]$finding.validationResolution) +
            '\s*\|[^|]*' +
            [regex]::Escape([string]$finding.effectiveSeverity) +
            '[^|]*\|[^|]*\|\s*$'
        if ($report -notmatch $adjudicationPattern) {
            Add-ValidationError "Security report does not contain the canonical adjudication row for finding '$($finding.findingId)'."
        }
    }

    if ([int]$synthesis.summary.unresolvedValidationCount -ne 0) {
        Add-ValidationError 'Security synthesis contains unresolved validation adjudications.'
    }
    if ($report -match '\{\{[^}]+\}\}|\bYYYY-MM-DD\b') {
        Add-ValidationError 'Security report contains unresolved template placeholders.'
    }
}

foreach ($errorMessage in $errors) {
    Write-Error $errorMessage
}
Write-Host "Crow security review validation: $($errors.Count) error(s)."
if ($errors.Count -gt 0) {
    exit 1
}
exit 0
