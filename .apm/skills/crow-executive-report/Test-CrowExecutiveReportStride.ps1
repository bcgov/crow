[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ReportDataPath,

    [Parameter(Mandatory)]
    [string]$SecurityReviewPath,

    [string]$SynthesisPath
)

$ErrorActionPreference = 'Stop'

function Get-RequiredProperty {
    param(
        [object]$Object,
        [string]$Name,
        [string]$Context
    )

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        throw "$Context is missing required property '$Name'."
    }
    return $property.Value
}

function Get-RequiredText {
    param(
        [object]$Object,
        [string]$Name,
        [string]$Context
    )

    $value = Get-RequiredProperty $Object $Name $Context
    if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) {
        throw "$Context property '$Name' must be non-empty text."
    }
    return $value
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
        throw "Security review frontmatter is missing '$Name'."
    }
    return $match.Groups[1].Value.Trim().Trim('"', "'")
}

function Get-StrideMarkdownRows {
    param(
        [string]$Report,
        [System.Collections.Generic.HashSet[string]]$EvidenceIds,
        [switch]$RequireLegacyHeader
    )

    $sectionMatch = [regex]::Match(
        $Report,
        '(?ms)^### STRIDE Threat Model Summary\s*\r?\n(?<section>.*?)(?=^## 12\. Security Finding Synthesis & Assurance\s*$)')
    if (-not $sectionMatch.Success) {
        throw 'Security review is missing the STRIDE Threat Model Summary section.'
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
    $headers = [System.Collections.Generic.List[object]]::new()
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($line in ($sectionMatch.Groups['section'].Value -split '\r?\n')) {
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
            $headers.Add($cells)
        }
        else {
            $rows.Add($cells)
        }
    }

    if ($headers.Count -ne 1) {
        throw "Security review must contain exactly one STRIDE table header; found $($headers.Count)."
    }
    $headerText = @($headers[0]) -join '|'
    $isLegacyHeader = $headerText -ceq ($legacyHeader -join '|')
    if ($RequireLegacyHeader) {
        if (-not $isLegacyHeader) {
            throw 'Legacy STRIDE source must use the canonical seven-column table.'
        }
    }
    elseif ($headerText -cne ($structuredHeader -join '|')) {
        throw 'Security synthesis schemaVersion 1.1 requires the canonical nine-column STRIDE table.'
    }
    if ($rows.Count -eq 0) {
        throw 'Security review STRIDE table must contain at least one component row.'
    }

    $columnCount = if ($isLegacyHeader) { $legacyHeader.Count } else { $structuredHeader.Count }
    $allowedRatings = @('High', 'Medium', 'Low', 'Unknown', 'N/A')
    $components = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    $normalizedRows = [System.Collections.Generic.List[object]]::new()
    foreach ($cells in $rows) {
        if ($cells.Count -ne $columnCount) {
            throw "Security review STRIDE row has $($cells.Count) cells; expected $columnCount."
        }
        $component = $cells[0]
        if ([string]::IsNullOrWhiteSpace($component) -or
            $component -match '[\r\n|]' -or
            -not $components.Add($component)) {
            throw "Security review contains an empty, unsafe, or duplicate STRIDE component '$component'."
        }
        for ($dimensionIndex = 1; $dimensionIndex -le 6; $dimensionIndex++) {
            if ($cells[$dimensionIndex] -cnotin $allowedRatings) {
                throw "STRIDE component '$component' has unsupported rating '$($cells[$dimensionIndex])'."
            }
        }
        $references = @()
        $rationale = ''
        if (-not $isLegacyHeader) {
            if ([string]::IsNullOrWhiteSpace($cells[7]) -or
                [string]::IsNullOrWhiteSpace($cells[8])) {
                throw "STRIDE component '$component' requires evidence IDs and rationale."
            }
            $references = @($cells[7] -split ',\s*')
            if (@($references | Select-Object -Unique).Count -ne $references.Count) {
                throw "STRIDE component '$component' contains duplicate evidence IDs."
            }
            foreach ($reference in $references) {
                if ($reference -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
                    throw "STRIDE component '$component' contains unsafe evidence ID '$reference'."
                }
                if ($null -eq $EvidenceIds) {
                    throw "STRIDE component '$component' evidence IDs cannot be resolved without a security synthesis."
                }
                if (-not $EvidenceIds.Contains($reference)) {
                    throw "STRIDE component '$component' references unresolved evidence '$reference'."
                }
            }
            $rationale = $cells[8]
        }

        $normalizedRows.Add([ordered]@{
            component = $component
            S = $cells[1]
            T = $cells[2]
            R = $cells[3]
            I = $cells[4]
            D = $cells[5]
            E = $cells[6]
            evidenceRefs = $references
            rationale = $rationale
        })
    }
    return ,@($normalizedRows)
}

function Assert-SameRatingRows {
    param(
        [object[]]$Actual,
        [object[]]$Expected,
        [string]$Context
    )

    if ($Actual.Count -ne $Expected.Count) {
        throw "$Context has $($Actual.Count) rows; expected $($Expected.Count)."
    }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        foreach ($property in @('component', 'S', 'T', 'R', 'I', 'D', 'E')) {
            if ([string]$Actual[$index].$property -cne [string]$Expected[$index].$property) {
                throw "$Context STRIDE row $($index + 1) differs at '$property'."
            }
        }
    }
}

function Test-FullPathEquals {
    param(
        [string]$Left,
        [string]$Right
    )

    $comparison = if ([System.IO.Path]::DirectorySeparatorChar -eq [char]92) {
        [System.StringComparison]::OrdinalIgnoreCase
    }
    else {
        [System.StringComparison]::Ordinal
    }
    return [string]::Equals(
        [System.IO.Path]::GetFullPath($Left),
        [System.IO.Path]::GetFullPath($Right),
        $comparison)
}

if (-not (Test-Path -LiteralPath $ReportDataPath -PathType Leaf)) {
    throw "Report data does not exist: $ReportDataPath"
}
if (-not (Test-Path -LiteralPath $SecurityReviewPath -PathType Leaf)) {
    throw "Security review does not exist: $SecurityReviewPath"
}

$reportData = Get-Content -LiteralPath $ReportDataPath -Raw -Encoding UTF8 | ConvertFrom-Json
$securityReview = Get-Content -LiteralPath $SecurityReviewPath -Raw -Encoding UTF8
$frontmatterMatch = [regex]::Match(
    $securityReview,
    '\A---\s*\r?\n(?<content>.*?)\r?\n---\s*\r?\n',
    [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $frontmatterMatch.Success) {
    throw 'Security review is missing YAML frontmatter.'
}
$frontmatter = $frontmatterMatch.Groups['content'].Value
$reportScope = Get-FrontmatterValue $frontmatter 'report_scope'
$serviceName = Get-FrontmatterValue $frontmatter 'service_name'
$servicePath = Get-FrontmatterValue $frontmatter 'service_path'
$reviewRevision = Get-FrontmatterValue $frontmatter 'source_revision'
if ([string]::IsNullOrWhiteSpace($reviewRevision) -or
    [string]::IsNullOrWhiteSpace($serviceName) -or
    [string]::IsNullOrWhiteSpace($servicePath)) {
    throw 'Security review frontmatter must include source_revision, service_name, and service_path.'
}
if ($reportScope -cnotin @('SingleApp', 'Monorepo')) {
    throw "Security review report_scope '$reportScope' is unsupported."
}

$reviewFullPath = [System.IO.Path]::GetFullPath($SecurityReviewPath)
if ([System.IO.Path]::GetFileName($reviewFullPath) -cne 'security-review.md') {
    throw 'Security review path must end in security-review.md.'
}
$reviewDirectory = [System.IO.Path]::GetDirectoryName($reviewFullPath)
$reviewDirectoryName = [System.IO.Path]::GetFileName($reviewDirectory)
if ($reportScope -ceq 'SingleApp') {
    if ($reviewDirectoryName -cne 'docs' -or $servicePath -cne '.') {
        throw 'Single-app security review must be docs/security-review.md with service_path ".".'
    }
    $repositoryRoot = [System.IO.Path]::GetDirectoryName($reviewDirectory)
    $expectedSynthesisArtifact = 'docs/security-review-synthesis.json'
}
else {
    $docsDirectory = [System.IO.Path]::GetDirectoryName($reviewDirectory)
    if ([System.IO.Path]::GetFileName($docsDirectory) -cne 'docs' -or
        $reviewDirectoryName -cne $serviceName) {
        throw "Monorepo security review must be docs/$serviceName/security-review.md."
    }
    if ($serviceName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        throw "Monorepo service_name is not a safe identifier: '$serviceName'."
    }
    $servicePathSegments = @($servicePath -split '[\\/]')
    if ($servicePath -match '^(?:[\\/]|[A-Za-z]:)' -or
        $servicePathSegments -contains '' -or
        $servicePathSegments -contains '.' -or
        $servicePathSegments -contains '..') {
        throw 'Monorepo service_path must be a repository-relative path without empty, "." or ".." segments.'
    }
    $repositoryRoot = [System.IO.Path]::GetDirectoryName($docsDirectory)
    $nativeServicePath = $servicePath.Replace(
        '/',
        [string][System.IO.Path]::DirectorySeparatorChar).Replace(
        '\',
        [string][System.IO.Path]::DirectorySeparatorChar)
    $resolvedServicePath = Join-Path $repositoryRoot $nativeServicePath
    if (-not (Test-Path -LiteralPath $resolvedServicePath -PathType Container)) {
        throw "Monorepo service_path does not resolve to a directory: $servicePath"
    }
    $expectedSynthesisArtifact = "docs/$serviceName/security-review-synthesis.json"
}
$expectedReportDataPath = Join-Path $reviewDirectory 'report-data.json'
if (-not (Test-FullPathEquals $ReportDataPath $expectedReportDataPath)) {
    throw "Report data must be adjacent to the scoped security review at '$expectedReportDataPath'."
}
$declaredSynthesis = [regex]::Match(
    $frontmatter,
    '(?m)^synthesis_artifact:\s*(.*?)\s*$')
$reviewHasSynthesis = $declaredSynthesis.Success

$synthesis = $null
$synthesisVersion = $null
$evidenceIds = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::Ordinal)
if (-not [string]::IsNullOrWhiteSpace($SynthesisPath)) {
    if (-not (Test-Path -LiteralPath $SynthesisPath -PathType Leaf)) {
        throw "Security synthesis does not exist: $SynthesisPath"
    }
    if (-not $reviewHasSynthesis) {
        throw 'A synthesis path was supplied, but the security review does not declare synthesis_artifact.'
    }
    $declaredArtifact = $declaredSynthesis.Groups[1].Value.Trim().Trim('"', "'")
    if ($declaredArtifact -cne $expectedSynthesisArtifact) {
        throw "Security review synthesis_artifact must be '$expectedSynthesisArtifact'."
    }
    $expectedSynthesisPath = [System.IO.Path]::GetFullPath(
        (Join-Path $reviewDirectory 'security-review-synthesis.json'))
    if (-not (Test-FullPathEquals $SynthesisPath $expectedSynthesisPath)) {
        throw 'Security synthesis must be adjacent to its security review.'
    }
    $synthesis = Get-Content -LiteralPath $SynthesisPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $synthesisVersion = Get-RequiredText $synthesis 'schemaVersion' 'Security synthesis'
    if ($synthesisVersion -notin @('1.0', '1.1')) {
        throw "Unsupported security synthesis schemaVersion '$synthesisVersion'."
    }
    if ((Get-RequiredText $synthesis 'sourceRevision' 'Security synthesis') -cne $reviewRevision) {
        throw 'Security synthesis sourceRevision does not match the security review.'
    }
    if ((Get-RequiredText $synthesis 'serviceName' 'Security synthesis') -cne $serviceName) {
        throw 'Security synthesis serviceName does not match the security review.'
    }
    $evidenceProperty = $synthesis.PSObject.Properties['evidence']
    if ($null -eq $evidenceProperty -or $evidenceProperty.Value -isnot [array]) {
        throw 'Security synthesis evidence must be an array.'
    }
    $evidenceRecords = @($evidenceProperty.Value)
    if ($synthesisVersion -ceq '1.1' -and $evidenceRecords.Count -eq 0) {
        throw 'Security synthesis schemaVersion 1.1 must contain evidence records.'
    }
    foreach ($evidence in $evidenceRecords) {
        if ($null -eq $evidence -or $evidence -is [string]) {
            throw 'Security synthesis contains an invalid evidence record.'
        }
        $evidenceId = Get-RequiredText $evidence 'id' 'Security synthesis evidence'
        if ($synthesisVersion -ceq '1.1' -and
            $evidenceId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
            throw "Security synthesis evidence ID '$evidenceId' is unsafe for Markdown."
        }
        if (-not $evidenceIds.Add($evidenceId)) {
            throw "Security synthesis contains duplicate evidence ID '$evidenceId'."
        }
        $evidencePath = Get-RequiredText $evidence 'path' "Security synthesis evidence '$evidenceId'"
        $evidencePathSegments = @($evidencePath -split '[\\/]')
        if ($evidencePath -match '^(?:[\\/]|[A-Za-z]:)' -or
            $evidencePath -match '^[A-Za-z][A-Za-z0-9+.-]*://' -or
            $evidencePathSegments -contains '' -or
            $evidencePathSegments -contains '.' -or
            $evidencePathSegments -contains '..') {
            throw "Security synthesis evidence '$evidenceId' path must be repository-relative."
        }
        $startLineValue = Get-RequiredProperty $evidence 'startLine' "Security synthesis evidence '$evidenceId'"
        $endLineValue = Get-RequiredProperty $evidence 'endLine' "Security synthesis evidence '$evidenceId'"
        $startLine = 0L
        $endLine = 0L
        $lineNumberStyle = [System.Globalization.NumberStyles]::Integer
        $invariantCulture = [System.Globalization.CultureInfo]::InvariantCulture
        if ($startLineValue -is [string] -or
            $startLineValue -is [bool] -or
            $startLineValue -isnot [System.ValueType] -or
            -not [long]::TryParse(
                [string]$startLineValue,
                $lineNumberStyle,
                $invariantCulture,
                [ref]$startLine) -or
            $startLine -lt 1) {
            throw "Security synthesis evidence '$evidenceId' startLine must be a positive integer."
        }
        if ($endLineValue -is [string] -or
            $endLineValue -is [bool] -or
            $endLineValue -isnot [System.ValueType] -or
            -not [long]::TryParse(
                [string]$endLineValue,
                $lineNumberStyle,
                $invariantCulture,
                [ref]$endLine) -or
            $endLine -lt $startLine) {
            throw "Security synthesis evidence '$evidenceId' endLine must be an integer greater than or equal to startLine."
        }
        [void](Get-RequiredText $evidence 'summary' "Security synthesis evidence '$evidenceId'")
    }
}
elseif ($reviewHasSynthesis) {
    throw 'Security review declares synthesis_artifact, but no synthesis path was supplied.'
}

$requireLegacyHeader = $null -eq $synthesis -or $synthesisVersion -ceq '1.0'
$markdownRows = @(Get-StrideMarkdownRows `
    $securityReview `
    $evidenceIds `
    -RequireLegacyHeader:$requireLegacyHeader)
if ($null -ne $synthesis -and $synthesisVersion -ceq '1.1') {
    $synthesisRowsProperty = $synthesis.PSObject.Properties['stride']
    if ($null -eq $synthesisRowsProperty -or
        $synthesisRowsProperty.Value -isnot [array] -or
        $synthesisRowsProperty.Value.Count -eq 0) {
        throw 'Security synthesis schemaVersion 1.1 must contain a non-empty stride array.'
    }
    $synthesisRows = @($synthesisRowsProperty.Value)
    $synthesisComponents = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    $allowedRatings = @('High', 'Medium', 'Low', 'Unknown', 'N/A')
    foreach ($row in $synthesisRows) {
        if ($null -eq $row -or $row -is [string]) {
            throw 'Security synthesis STRIDE rows must be objects.'
        }
        $component = Get-RequiredText $row 'component' 'Security synthesis STRIDE row'
        if ($component -match '[\r\n|]' -or -not $synthesisComponents.Add($component)) {
            throw "Security synthesis contains an unsafe or duplicate STRIDE component '$component'."
        }
        foreach ($dimension in @('S', 'T', 'R', 'I', 'D', 'E')) {
            $rating = Get-RequiredText $row $dimension "Security synthesis STRIDE component '$component'"
            if ($rating -cnotin $allowedRatings) {
                throw "Security synthesis STRIDE component '$component' has unsupported $dimension rating '$rating'."
            }
        }
        $rationale = Get-RequiredText $row 'rationale' "Security synthesis STRIDE component '$component'"
        if ($rationale -match '[\r\n|]') {
            throw "Security synthesis STRIDE component '$component' has unsafe rationale text."
        }
        $referencesProperty = $row.PSObject.Properties['evidenceRefs']
        if ($null -eq $referencesProperty -or
            $referencesProperty.Value -isnot [array] -or
            $referencesProperty.Value.Count -eq 0) {
            throw "Security synthesis STRIDE component '$component' must reference evidence."
        }
        $references = @($referencesProperty.Value)
        foreach ($reference in $references) {
            if ($reference -isnot [string] -or
                $reference -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
                throw "Security synthesis STRIDE component '$component' has an invalid evidence ID."
            }
            if (-not $evidenceIds.Contains($reference)) {
                throw "Security synthesis STRIDE component '$component' references unresolved evidence '$reference'."
            }
        }
        if (@($references | Select-Object -Unique).Count -ne $references.Count) {
            throw "Security synthesis STRIDE component '$component' contains duplicate evidence IDs."
        }
    }
    if ($synthesisRows.Count -ne $markdownRows.Count) {
        throw 'Security synthesis and security review STRIDE row counts do not match.'
    }
    for ($index = 0; $index -lt $synthesisRows.Count; $index++) {
        foreach ($property in @('component', 'S', 'T', 'R', 'I', 'D', 'E', 'rationale')) {
            if ([string]$synthesisRows[$index].$property -cne [string]$markdownRows[$index].$property) {
                throw "Security synthesis and security review STRIDE row $($index + 1) differ at '$property'."
            }
        }
        if ((@($synthesisRows[$index].evidenceRefs) -join ', ') -cne
            (@($markdownRows[$index].evidenceRefs) -join ', ')) {
            throw "Security synthesis and security review STRIDE row $($index + 1) evidence IDs do not match."
        }
    }
    $expectedRows = $synthesisRows
}
else {
    if ($null -ne $synthesis -and
        $null -ne $synthesis.PSObject.Properties['stride']) {
        throw 'Security synthesis schemaVersion 1.0 must not contain a stride property.'
    }
    $expectedRows = $markdownRows
}

$reportStrideProperty = $reportData.PSObject.Properties['stride']
if ($null -eq $reportStrideProperty -or
    $reportStrideProperty.Value -isnot [array] -or
    $reportStrideProperty.Value.Count -eq 0) {
    throw 'Report data must contain a non-empty stride array before an executive report is generated.'
}
$reportRows = @($reportStrideProperty.Value)
$reportComponents = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase)
$allowedRatings = @('High', 'Medium', 'Low', 'Unknown', 'N/A')
foreach ($row in $reportRows) {
    $component = Get-RequiredText $row 'component' 'Report STRIDE row'
    if ($component -match '[\r\n|]' -or -not $reportComponents.Add($component)) {
        throw "Report data contains an unsafe or duplicate STRIDE component '$component'."
    }
    foreach ($dimension in @('S', 'T', 'R', 'I', 'D', 'E')) {
        $rating = Get-RequiredText $row $dimension "Report STRIDE component '$component'"
        if ($rating -cnotin $allowedRatings) {
            throw "Report STRIDE component '$component' has unsupported $dimension rating '$rating'."
        }
    }
}
Assert-SameRatingRows $reportRows $expectedRows 'Report data'
Write-Host 'Crow executive report STRIDE validation: passed.'
