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
    $synthesisVersion = [string]$synthesis.schemaVersion
    if ($synthesisVersion -cnotin @('1.0', '1.1')) {
        Add-ValidationError "Security synthesis schemaVersion '$synthesisVersion' is unsupported; expected '1.0' or '1.1'."
    }

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

    $hasStructuredStride = $synthesisVersion -ceq '1.1'
    $strideRowsProperty = $synthesis.PSObject.Properties['stride']
    $strideRows = @()
    if ($hasStructuredStride) {
        if ($null -eq $strideRowsProperty -or
            $strideRowsProperty.Value -isnot [array] -or
            $strideRowsProperty.Value.Count -eq 0) {
            Add-ValidationError 'Security synthesis schemaVersion 1.1 must contain a non-empty stride array.'
        }
        else {
            $strideRows = @($strideRowsProperty.Value)
        }
    }
    elseif ($null -ne $strideRowsProperty) {
        Add-ValidationError 'Security synthesis schemaVersion 1.0 must not contain a stride property.'
    }

    $strideEvidenceIds = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal)
    $evidenceProperty = $synthesis.PSObject.Properties['evidence']
    if ($null -eq $evidenceProperty -or $evidenceProperty.Value -isnot [array]) {
        Add-ValidationError 'Security synthesis must contain an evidence array.'
    }
    else {
        $evidenceRecords = @($evidenceProperty.Value)
        if ($hasStructuredStride -and $evidenceRecords.Count -eq 0) {
            Add-ValidationError 'Security synthesis schemaVersion 1.1 must contain evidence records.'
        }
        foreach ($evidence in $evidenceRecords) {
            if ($null -eq $evidence -or $evidence -is [string]) {
                Add-ValidationError 'Security synthesis contains an invalid evidence record.'
                continue
            }
            $evidenceId = $evidence.PSObject.Properties['id']
            if ($null -eq $evidenceId -or
                $evidenceId.Value -isnot [string] -or
                [string]::IsNullOrWhiteSpace($evidenceId.Value) -or
                ($hasStructuredStride -and
                    $evidenceId.Value -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$')) {
                Add-ValidationError 'Security synthesis evidence requires a valid string ID.'
                continue
            }
            if (-not $strideEvidenceIds.Add($evidenceId.Value)) {
                Add-ValidationError "Security synthesis contains duplicate evidence ID '$($evidenceId.Value)'."
            }

            $evidencePathProperty = $evidence.PSObject.Properties['path']
            if ($null -eq $evidencePathProperty -or
                $evidencePathProperty.Value -isnot [string] -or
                [string]::IsNullOrWhiteSpace($evidencePathProperty.Value)) {
                Add-ValidationError "Evidence '$($evidenceId.Value)' requires a repository-relative path."
            }
            else {
                $evidencePath = $evidencePathProperty.Value
                $evidencePathSegments = @($evidencePath -split '[\\/]')
                if ($evidencePath -match '^(?:[\\/]|[A-Za-z]:)' -or
                    $evidencePath -match '^[A-Za-z][A-Za-z0-9+.-]*://' -or
                    $evidencePathSegments -contains '' -or
                    $evidencePathSegments -contains '.' -or
                    $evidencePathSegments -contains '..') {
                    Add-ValidationError "Evidence '$($evidenceId.Value)' path must be repository-relative."
                }
            }

            $startLineProperty = $evidence.PSObject.Properties['startLine']
            $endLineProperty = $evidence.PSObject.Properties['endLine']
            $startLine = 0L
            $endLine = 0L
            $lineNumberStyle = [System.Globalization.NumberStyles]::Integer
            $invariantCulture = [System.Globalization.CultureInfo]::InvariantCulture
            if ($null -eq $startLineProperty -or
                $startLineProperty.Value -is [string] -or
                $startLineProperty.Value -is [bool] -or
                $startLineProperty.Value -isnot [System.ValueType] -or
                -not [long]::TryParse(
                    [string]$startLineProperty.Value,
                    $lineNumberStyle,
                    $invariantCulture,
                    [ref]$startLine) -or
                $startLine -lt 1) {
                Add-ValidationError "Evidence '$($evidenceId.Value)' startLine must be a positive integer."
            }
            if ($null -eq $endLineProperty -or
                $endLineProperty.Value -is [string] -or
                $endLineProperty.Value -is [bool] -or
                $endLineProperty.Value -isnot [System.ValueType] -or
                -not [long]::TryParse(
                    [string]$endLineProperty.Value,
                    $lineNumberStyle,
                    $invariantCulture,
                    [ref]$endLine) -or
                $endLine -lt $startLine) {
                Add-ValidationError "Evidence '$($evidenceId.Value)' endLine must be an integer greater than or equal to startLine."
            }

            $summaryProperty = $evidence.PSObject.Properties['summary']
            if ($null -eq $summaryProperty -or
                $summaryProperty.Value -isnot [string] -or
                [string]::IsNullOrWhiteSpace($summaryProperty.Value)) {
                Add-ValidationError "Evidence '$($evidenceId.Value)' requires a non-empty summary."
            }
        }
    }
    $strideComponents = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    $strideDimensions = @('S', 'T', 'R', 'I', 'D', 'E')
    $strideRatings = @('High', 'Medium', 'Low', 'Unknown', 'N/A')
    foreach ($row in $strideRows) {
        if ($null -eq $row) {
            Add-ValidationError 'Security synthesis contains a null STRIDE row.'
            continue
        }
        $component = $row.component
        if ($component -isnot [string] -or
            [string]::IsNullOrWhiteSpace($component) -or
            $component -match '[\r\n|]') {
            Add-ValidationError 'Every STRIDE row requires a component name without Markdown pipes or line breaks.'
            continue
        }
        if (-not $strideComponents.Add($component)) {
            Add-ValidationError "Security synthesis contains duplicate STRIDE component '$component'."
        }
        foreach ($dimension in $strideDimensions) {
            $rating = $row.PSObject.Properties[$dimension]
            if ($null -eq $rating -or
                $rating.Value -isnot [string] -or
                $rating.Value -cnotin $strideRatings) {
                Add-ValidationError "STRIDE component '$component' requires a supported $dimension rating."
            }
        }
        if ($row.rationale -isnot [string] -or
            [string]::IsNullOrWhiteSpace($row.rationale) -or
            $row.rationale -match '[\r\n|]') {
            Add-ValidationError "STRIDE component '$component' requires rationale without Markdown pipes or line breaks."
        }
        $referencesProperty = $row.PSObject.Properties['evidenceRefs']
        if ($null -eq $referencesProperty -or
            $referencesProperty.Value -isnot [array] -or
            $referencesProperty.Value.Count -eq 0) {
            Add-ValidationError "STRIDE component '$component' must reference at least one evidence item."
            continue
        }
        $referenceIds = @($referencesProperty.Value)
        foreach ($reference in $referenceIds) {
            if ($reference -isnot [string] -or
                $reference -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
                Add-ValidationError "STRIDE component '$component' evidence references must be table-safe string IDs."
            }
        }
        if (@($referenceIds | Select-Object -Unique).Count -ne $referenceIds.Count) {
            Add-ValidationError "STRIDE component '$component' contains duplicate evidence references."
        }
        foreach ($reference in $referenceIds) {
            if ($reference -isnot [string] -or
                -not $strideEvidenceIds.Contains([string]$reference)) {
                Add-ValidationError "STRIDE component '$component' references unresolved evidence '$reference'."
            }
        }
    }

    $strideSectionMatch = [regex]::Match(
        $report,
        '(?ms)^### STRIDE Threat Model Summary\s*\r?\n(?<section>.*?)(?=^## 12\. Security Finding Synthesis & Assurance\s*$)')
    if (-not $strideSectionMatch.Success) {
        Add-ValidationError 'Security report is missing the STRIDE Threat Model Summary table.'
    }
    else {
        $markdownStrideHeaders = [System.Collections.Generic.List[object]]::new()
        $markdownStrideRows = [System.Collections.Generic.List[object]]::new()
        foreach ($line in ($strideSectionMatch.Groups['section'].Value -split '\r?\n')) {
            if ($line -notmatch '^\s*\|(?<cells>.*?)\|\s*$') {
                continue
            }
            $cells = @(
                $matches['cells'] -split '\s*\|\s*' |
                    ForEach-Object { $_.Trim() }
            )
            if (@($cells | Where-Object { $_ -notmatch '^:?-+:?$' }).Count -eq 0) {
                continue
            }
            if ($cells.Count -gt 0 -and $cells[0] -ceq 'Component') {
                $markdownStrideHeaders.Add($cells)
                continue
            }
            $markdownStrideRows.Add($cells)
        }

        $legacyHeader = @(
            'Component', 'Spoofing', 'Tampering', 'Repudiation',
            'Info Disclosure', 'DoS', 'Elevation of Privilege'
        )
        $structuredHeader = @(
            'Component', 'Spoofing', 'Tampering', 'Repudiation',
            'Information Disclosure', 'Denial of Service',
            'Elevation of Privilege', 'Evidence IDs', 'Rationale'
        )
        if ($markdownStrideHeaders.Count -ne 1) {
            Add-ValidationError "Security report must contain exactly one STRIDE table header; found $($markdownStrideHeaders.Count)."
        }
        $headerCells = @()
        if ($markdownStrideHeaders.Count -eq 1) {
            $headerCells = @($markdownStrideHeaders[0])
            $headerText = $headerCells -join '|'
            $structuredHeaderText = $structuredHeader -join '|'
            $legacyHeaderText = $legacyHeader -join '|'
            $validHeader = if ($hasStructuredStride) {
                $headerText -ceq $structuredHeaderText
            }
            else {
                $headerText -ceq $legacyHeaderText
            }
            if (-not $validHeader) {
                Add-ValidationError "Security report STRIDE table header is not in the canonical category order for schemaVersion $synthesisVersion."
            }
        }
        if ($markdownStrideRows.Count -eq 0) {
            Add-ValidationError 'Security report STRIDE table must contain at least one component row.'
        }

        $markdownStrideComponents = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase)
        $strideRatings = @('High', 'Medium', 'Low', 'Unknown', 'N/A')
        foreach ($markdownRow in $markdownStrideRows) {
            $cells = @($markdownRow)
            if ($headerCells.Count -eq 0 -or $cells.Count -ne $headerCells.Count) {
                Add-ValidationError "Security report STRIDE row has $($cells.Count) cells; expected $($headerCells.Count)."
                continue
            }
            $component = [string]$cells[0]
            if ([string]::IsNullOrWhiteSpace($component) -or
                $component -match '[\r\n|]') {
                Add-ValidationError 'Every security report STRIDE row requires a safe component name.'
                continue
            }
            if (-not $markdownStrideComponents.Add($component)) {
                Add-ValidationError "Security report contains duplicate STRIDE component '$component'."
            }
            for ($dimensionIndex = 1; $dimensionIndex -le 6; $dimensionIndex++) {
                if ($cells[$dimensionIndex] -cnotin $strideRatings) {
                    Add-ValidationError "Security report STRIDE component '$component' has unsupported rating '$($cells[$dimensionIndex])'."
                }
            }
            if ($headerCells.Count -eq 9) {
                $referenceIds = @($cells[7] -split ',\s*')
                if ([string]::IsNullOrWhiteSpace($cells[7]) -or
                    [string]::IsNullOrWhiteSpace($cells[8])) {
                    Add-ValidationError "Security report STRIDE component '$component' requires evidence IDs and rationale."
                }
                foreach ($reference in $referenceIds) {
                    if ($reference -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
                        Add-ValidationError "Security report STRIDE component '$component' contains an unsafe evidence ID."
                    }
                    elseif (-not $strideEvidenceIds.Contains($reference)) {
                        Add-ValidationError "Security report STRIDE component '$component' references unresolved evidence '$reference'."
                    }
                }
            }
        }

        if ($hasStructuredStride) {
            if ($markdownStrideRows.Count -ne $strideRows.Count) {
                Add-ValidationError "Security report has $($markdownStrideRows.Count) STRIDE rows; synthesis has $($strideRows.Count)."
            }
            $rowsToCompare = [Math]::Min($markdownStrideRows.Count, $strideRows.Count)
            for ($index = 0; $index -lt $rowsToCompare; $index++) {
                $row = $strideRows[$index]
                $expectedCells = @(
                    [string]$row.component,
                    [string]$row.S,
                    [string]$row.T,
                    [string]$row.R,
                    [string]$row.I,
                    [string]$row.D,
                    [string]$row.E,
                    (@($row.evidenceRefs) -join ', '),
                    [string]$row.rationale
                )
                $actualCells = @($markdownStrideRows[$index])
                if ($actualCells.Count -ne $expectedCells.Count) {
                    Add-ValidationError "Security report STRIDE row $($index + 1) has $($actualCells.Count) cells; expected $($expectedCells.Count)."
                    continue
                }
                for ($cellIndex = 0; $cellIndex -lt $expectedCells.Count; $cellIndex++) {
                    if ($actualCells[$cellIndex] -cne $expectedCells[$cellIndex]) {
                        Add-ValidationError "Security report STRIDE row '$($row.component)' does not match synthesis cell $($cellIndex + 1)."
                    }
                }
            }
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
