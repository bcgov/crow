[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$InputPath,

    [Parameter(Mandatory)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

function Get-RequiredValue {
    param(
        [object]$Object,
        [string]$Name,
        [string]$Context
    )

    if (-not ($Object.PSObject.Properties.Name -contains $Name)) {
        throw "$Context is missing required property '$Name'."
    }
    $value = $Object.$Name
    if ($null -eq $value -or
        ($value -is [string] -and [string]::IsNullOrWhiteSpace($value))) {
        throw "$Context property '$Name' cannot be empty."
    }
    return $value
}

function Get-OptionalValue {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Default
    )

    if ($Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $Default
}

function Get-Sha256 {
    param([string]$Value)

    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return ([System.BitConverter]::ToString(
            $algorithm.ComputeHash($bytes))).Replace('-', '')
    }
    finally {
        $algorithm.Dispose()
    }
}

function Get-SeverityWeight {
    param([string]$Severity)

    switch ($Severity.ToLowerInvariant()) {
        'critical' { return 16.0 }
        'high' { return 8.0 }
        'medium' { return 4.0 }
        'low' { return 1.0 }
        'informational' { return 0.0 }
        default { throw "Unsupported severity '$Severity'." }
    }
}

function Get-ConfidenceWeight {
    param([string]$Classification)

    switch ($Classification.ToLowerInvariant()) {
        'confirmed' { return 1.0 }
        'probable' { return 0.5 }
        'informational' { return 0.0 }
        default { throw "Unsupported finding classification '$Classification'." }
    }
}

function Get-ExposureWeight {
    param([string]$Exposure)

    switch ($Exposure.ToLowerInvariant()) {
        'external' { return 1.25 }
        'crossservice' { return 1.15 }
        'internal' { return 1.0 }
        default { throw "Unsupported component exposure '$Exposure'." }
    }
}

function Assert-EvidenceReferences {
    param(
        [object[]]$References,
        [System.Collections.Generic.HashSet[string]]$EvidenceIds,
        [string]$Context,
        [switch]$AllowEmpty
    )

    if (-not $AllowEmpty -and $References.Count -eq 0) {
        throw "$Context must reference at least one evidence item."
    }
    foreach ($reference in $References) {
        if (-not $EvidenceIds.Contains([string]$reference)) {
            throw "$Context references unknown evidence '$reference'."
        }
    }
}

$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
$inputData = [System.IO.File]::ReadAllText($resolvedInput) | ConvertFrom-Json
$schemaVersion = [string](Get-RequiredValue $inputData 'schemaVersion' 'Input')
if ($schemaVersion -notin @('1.0', '1.1')) {
    throw "Unsupported synthesis schemaVersion '$schemaVersion'."
}

$serviceName = [string](Get-RequiredValue $inputData 'serviceName' 'Input')
$sourceRevision = [string](Get-RequiredValue $inputData 'sourceRevision' 'Input')
$evidence = @(Get-RequiredValue $inputData 'evidence' 'Input')
$components = @(Get-RequiredValue $inputData 'components' 'Input')
$findings = @(Get-RequiredValue $inputData 'findings' 'Input')
$themes = @(Get-OptionalValue $inputData 'themes' @())
$chains = @(Get-OptionalValue $inputData 'chains' @())
$strideProperty = $inputData.PSObject.Properties['stride']
if ($schemaVersion -eq '1.1') {
    if ($null -eq $strideProperty -or $strideProperty.Value -isnot [array] -or
        $strideProperty.Value.Count -eq 0) {
        throw "Input property 'stride' must be a non-empty array for schemaVersion 1.1."
    }
    $stride = $strideProperty.Value
}
else {
    if ($null -ne $strideProperty) {
        throw "Input property 'stride' is not supported for schemaVersion 1.0."
    }
    $stride = @()
}

$evidenceIds = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::Ordinal)
$normalizedEvidence = [System.Collections.Generic.List[object]]::new()
foreach ($item in $evidence) {
    $evidenceIdValue = Get-RequiredValue $item 'id' 'Evidence'
    if ($evidenceIdValue -isnot [string]) {
        throw 'Evidence property ''id'' must be a string.'
    }
    $evidenceId = $evidenceIdValue
    if (-not $evidenceIds.Add($evidenceId)) {
        throw "Duplicate evidence ID '$evidenceId'."
    }

    $evidencePathValue = Get-RequiredValue $item 'path' "Evidence '$evidenceId'"
    if ($evidencePathValue -isnot [string]) {
        throw "Evidence '$evidenceId' property 'path' must be a string."
    }
    $evidencePath = $evidencePathValue
    $pathSegments = @($evidencePath -split '[\\/]')
    if ($evidencePath -match '^(?:[\\/]|[A-Za-z]:)' -or
        $evidencePath -match '^[A-Za-z][A-Za-z0-9+.-]*://' -or
        $pathSegments -contains '' -or
        $pathSegments -contains '.' -or
        $pathSegments -contains '..') {
        throw "Evidence '$evidenceId' path must be a repository-relative file path."
    }

    $startLineValue = Get-RequiredValue $item 'startLine' "Evidence '$evidenceId'"
    $endLineValue = Get-RequiredValue $item 'endLine' "Evidence '$evidenceId'"
    $lineNumberStyle = [System.Globalization.NumberStyles]::Integer
    $invariantCulture = [System.Globalization.CultureInfo]::InvariantCulture
    [long]$startLine = 0
    [long]$endLine = 0
    if ($startLineValue -is [string] -or
        $startLineValue -is [bool] -or
        $startLineValue -isnot [System.ValueType] -or
        -not [long]::TryParse(
            [string]$startLineValue,
            $lineNumberStyle,
            $invariantCulture,
            [ref]$startLine) -or
        $startLine -lt 1) {
        throw "Evidence '$evidenceId' property 'startLine' must be a positive integer."
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
        throw "Evidence '$evidenceId' property 'endLine' must be an integer greater than or equal to startLine."
    }

    $summaryValue = Get-RequiredValue $item 'summary' "Evidence '$evidenceId'"
    if ($summaryValue -isnot [string]) {
        throw "Evidence '$evidenceId' property 'summary' must be a string."
    }
    $normalizedEvidence.Add([ordered]@{
        id = $evidenceId
        path = $evidencePath
        startLine = $startLine
        endLine = $endLine
        summary = $summaryValue
    })
}

$normalizedStride = [System.Collections.Generic.List[object]]::new()
$strideComponents = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase)
$strideDimensions = @('S', 'T', 'R', 'I', 'D', 'E')
$strideRatings = @('High', 'Medium', 'Low', 'Unknown', 'N/A')
foreach ($row in $stride) {
    if ($null -eq $row -or $row -is [string]) {
        throw 'Each STRIDE row must be an object.'
    }
    $componentValue = Get-RequiredValue $row 'component' 'STRIDE row'
    if ($componentValue -isnot [string] -or $componentValue -match '[\r\n|]') {
        throw 'STRIDE component must be text without Markdown pipes or line breaks.'
    }
    $componentName = $componentValue.Trim()
    if (-not $strideComponents.Add($componentName)) {
        throw "Duplicate STRIDE component '$componentName'."
    }

    $normalizedRow = [ordered]@{ component = $componentName }
    foreach ($dimension in $strideDimensions) {
        $ratingValue = Get-RequiredValue $row $dimension "STRIDE component '$componentName'"
        if ($ratingValue -isnot [string] -or $ratingValue -cnotin $strideRatings) {
            throw "STRIDE component '$componentName' has unsupported $dimension rating '$ratingValue'."
        }
        $normalizedRow[$dimension] = $ratingValue
    }

    $evidenceRefsProperty = $row.PSObject.Properties['evidenceRefs']
    if ($null -eq $evidenceRefsProperty -or
        $evidenceRefsProperty.Value -isnot [array] -or
        $evidenceRefsProperty.Value.Count -eq 0) {
        throw "STRIDE component '$componentName' must reference at least one evidence item."
    }
    $evidenceRefs = @($evidenceRefsProperty.Value)
    foreach ($reference in $evidenceRefs) {
        if ($reference -isnot [string] -or
            $reference -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
            throw "STRIDE component '$componentName' evidence references must be table-safe string IDs."
        }
    }
    if (@($evidenceRefs | Select-Object -Unique).Count -ne $evidenceRefs.Count) {
        throw "STRIDE component '$componentName' contains duplicate evidence references."
    }
    Assert-EvidenceReferences `
        -References $evidenceRefs `
        -EvidenceIds $evidenceIds `
        -Context "STRIDE component '$componentName'"
    $normalizedRow.evidenceRefs = $evidenceRefs

    $rationaleValue = Get-RequiredValue $row 'rationale' "STRIDE component '$componentName'"
    if ($rationaleValue -isnot [string] -or $rationaleValue -match '[\r\n|]') {
        throw "STRIDE component '$componentName' rationale must be text without Markdown pipes or line breaks."
    }
    $normalizedRow.rationale = $rationaleValue.Trim()
    $normalizedStride.Add($normalizedRow)
}

$componentMap = @{}
foreach ($component in $components) {
    $name = [string](Get-RequiredValue $component 'name' 'Component')
    if ($name -notmatch '^[A-Za-z0-9][A-Za-z0-9._ -]*$') {
        throw "Component name contains unsupported characters: '$name'."
    }
    $exposure = [string](Get-RequiredValue $component 'exposure' "Component '$name'")
    Get-ExposureWeight $exposure | Out-Null
    if ($componentMap.ContainsKey($name)) {
        throw "Duplicate component '$name'."
    }
    $componentMap[$name] = $component
}
if ($componentMap.Count -eq 0) {
    throw 'Input must contain at least one component.'
}

$findingMap = @{}
$normalizedFindings = [System.Collections.Generic.List[object]]::new()
$unresolvedAdjudications = [System.Collections.Generic.List[string]]::new()
foreach ($finding in $findings) {
    $findingId = [string](Get-RequiredValue $finding 'findingId' 'Finding')
    if ($findingId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        throw "Finding ID contains unsupported characters: '$findingId'."
    }
    if ($findingMap.ContainsKey($findingId)) {
        throw "Duplicate finding ID '$findingId'."
    }

    $title = [string](Get-RequiredValue $finding 'title' "Finding '$findingId'")
    $severity = [string](Get-RequiredValue $finding 'severity' "Finding '$findingId'")
    $classification = [string](Get-RequiredValue $finding 'classification' "Finding '$findingId'")
    Get-SeverityWeight $severity | Out-Null
    Get-ConfidenceWeight $classification | Out-Null

    $findingComponents = @(Get-RequiredValue $finding 'components' "Finding '$findingId'")
    $domains = @(Get-RequiredValue $finding 'domains' "Finding '$findingId'")
    if ($findingComponents.Count -eq 0 -or $domains.Count -eq 0) {
        throw "Finding '$findingId' must include at least one component and domain."
    }
    foreach ($componentName in $findingComponents) {
        if (-not $componentMap.ContainsKey([string]$componentName)) {
            throw "Finding '$findingId' references unknown component '$componentName'."
        }
    }

    $active = $true
    $effectiveSeverity = $severity
    $validationDisposition = 'NotReviewed'
    $validationResolution = 'NotRequired'
    $validation = Get-OptionalValue $finding 'validation' $null
    if ($null -ne $validation) {
        $validationDisposition = [string](
            Get-RequiredValue $validation 'disposition' "Finding '$findingId' validation")
        $validationResolution = [string](
            Get-RequiredValue $validation 'resolution' "Finding '$findingId' validation")
        if ($validationDisposition -notin @(
            'Confirmed',
            'PartiallyConfirmed',
            'Disputed',
            'Rejected',
            'Unknown')) {
            throw "Finding '$findingId' has unsupported validation disposition '$validationDisposition'."
        }
        if ($validationResolution -notin @(
            'Accepted',
            'Adjusted',
            'Removed',
            'Pending')) {
            throw "Finding '$findingId' has unsupported validation resolution '$validationResolution'."
        }
        if ($validationResolution -eq 'Pending') {
            $unresolvedAdjudications.Add($findingId)
        }

        $adjustedSeverity = [string](Get-OptionalValue $validation 'adjustedSeverity' '')
        $rationale = [string](Get-OptionalValue $validation 'rationale' '')
        if (-not [string]::IsNullOrWhiteSpace($adjustedSeverity)) {
            Get-SeverityWeight $adjustedSeverity | Out-Null
            if ($validationResolution -ne 'Adjusted') {
                throw "Finding '$findingId' has adjustedSeverity without an Adjusted resolution."
            }
            $effectiveSeverity = $adjustedSeverity
        }
        if ($validationResolution -in @('Adjusted', 'Removed') -and
            [string]::IsNullOrWhiteSpace($rationale)) {
            throw "Finding '$findingId' requires a rationale for the '$validationResolution' resolution."
        }

        $validCombination = switch ($validationDisposition) {
            'Confirmed' {
                $validationResolution -eq 'Accepted' -or
                    $validationResolution -eq 'Adjusted'
            }
            'PartiallyConfirmed' {
                $validationResolution -in @('Adjusted', 'Removed')
            }
            'Disputed' {
                $validationResolution -in @('Adjusted', 'Removed')
            }
            'Rejected' {
                $validationResolution -eq 'Removed'
            }
            'Unknown' {
                $validationResolution -in @('Adjusted', 'Removed')
            }
        }
        if (-not $validCombination -and $validationResolution -ne 'Pending') {
            throw "Finding '$findingId' has invalid validation combination '$validationDisposition/$validationResolution'."
        }
        if ($validationResolution -eq 'Accepted' -and
            -not [string]::IsNullOrWhiteSpace($adjustedSeverity)) {
            throw "Finding '$findingId' cannot adjust severity with an Accepted resolution."
        }
        if ($validationResolution -eq 'Removed') {
            $active = $false
        }
    }

    $normalized = [ordered]@{
        findingId = $findingId
        title = $title
        severity = $severity
        effectiveSeverity = $effectiveSeverity
        classification = $classification
        components = @($findingComponents)
        domains = @($domains)
        active = $active
        validationDisposition = $validationDisposition
        validationResolution = $validationResolution
    }
    $findingMap[$findingId] = $normalized
    $normalizedFindings.Add($normalized)
}

if ($unresolvedAdjudications.Count -gt 0) {
    throw "Unresolved validation adjudication: $($unresolvedAdjudications -join ', ')."
}

$normalizedThemes = [System.Collections.Generic.List[object]]::new()
$themeIds = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::Ordinal)
foreach ($theme in $themes) {
    $themeId = [string](Get-RequiredValue $theme 'themeId' 'Theme')
    if ($themeId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        throw "Theme ID contains unsupported characters: '$themeId'."
    }
    if (-not $themeIds.Add($themeId)) {
        throw "Duplicate theme ID '$themeId'."
    }
    $sourceIds = @(Get-RequiredValue $theme 'sourceFindingIds' "Theme '$themeId'")
    if (@($sourceIds | Select-Object -Unique).Count -lt 2) {
        throw "Theme '$themeId' must reference at least two distinct findings."
    }
    $domainSet = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    foreach ($sourceId in $sourceIds) {
        if (-not $findingMap.ContainsKey([string]$sourceId) -or
            -not $findingMap[[string]$sourceId].active) {
            throw "Theme '$themeId' references unknown or inactive finding '$sourceId'."
        }
        foreach ($domain in $findingMap[[string]$sourceId].domains) {
            $domainSet.Add([string]$domain) | Out-Null
        }
    }
    if ($domainSet.Count -lt 2) {
        throw "Theme '$themeId' must span at least two finding domains."
    }
    $normalizedThemes.Add([ordered]@{
        themeId = $themeId
        title = [string](Get-RequiredValue $theme 'title' "Theme '$themeId'")
        sourceFindingIds = @($sourceIds)
        domains = @($domainSet | Sort-Object)
    })
}

$normalizedChains = [System.Collections.Generic.List[object]]::new()
$chainIds = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::Ordinal)
foreach ($chain in $chains) {
    $name = [string](Get-RequiredValue $chain 'name' 'Chain')
    $sourceIds = @(Get-RequiredValue $chain 'sourceFindingIds' "Chain '$name'")
    if (@($sourceIds | Select-Object -Unique).Count -lt 2) {
        throw "Chain '$name' must reference at least two distinct findings."
    }
    foreach ($sourceId in $sourceIds) {
        if (-not $findingMap.ContainsKey([string]$sourceId) -or
            -not $findingMap[[string]$sourceId].active) {
            throw "Chain '$name' references unknown or inactive finding '$sourceId'."
        }
        if ($findingMap[[string]$sourceId].validationDisposition -eq 'NotReviewed') {
            throw "Chain '$name' source finding '$sourceId' requires validation adjudication."
        }
    }

    $edges = @(Get-RequiredValue $chain 'edges' "Chain '$name'")
    if ($edges.Count -eq 0) {
        throw "Chain '$name' must contain at least one edge."
    }
    $sourceOrder = @{}
    for ($sourceIndex = 0; $sourceIndex -lt $sourceIds.Count; $sourceIndex++) {
        $sourceOrder[[string]$sourceIds[$sourceIndex]] = $sourceIndex
    }
    $edgeKeys = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal)
    $outbound = @{}
    foreach ($sourceId in $sourceIds) {
        $outbound[[string]$sourceId] = [System.Collections.Generic.List[string]]::new()
    }
    foreach ($edge in $edges) {
        $from = [string](Get-RequiredValue $edge 'from' "Chain '$name' edge")
        $to = [string](Get-RequiredValue $edge 'to' "Chain '$name' edge")
        $type = [string](Get-RequiredValue $edge 'type' "Chain '$name' edge")
        if ($from -eq $to -or $sourceIds -notcontains $from -or $sourceIds -notcontains $to) {
            throw "Chain '$name' contains an invalid edge '$from' -> '$to'."
        }
        if ($type -notin @('contributes-to', 'root-cause-of', 'related-to')) {
            throw "Chain '$name' contains unsupported edge type '$type'."
        }
        if ($sourceOrder[$from] -ge $sourceOrder[$to]) {
            throw "Chain '$name' edge '$from' -> '$to' violates source finding order."
        }
        $edgeKey = "$from|$to|$type"
        if (-not $edgeKeys.Add($edgeKey)) {
            throw "Chain '$name' contains duplicate edge '$from' -> '$to' ($type)."
        }
        $outbound[$from].Add($to)
        Assert-EvidenceReferences `
            -References @(Get-RequiredValue $edge 'evidenceRefs' "Chain '$name' edge") `
            -EvidenceIds $evidenceIds `
            -Context "Chain '$name' edge '$from' -> '$to'"
    }

    $reachable = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal)
    $pending = [System.Collections.Generic.Queue[string]]::new()
    $pending.Enqueue([string]$sourceIds[0])
    while ($pending.Count -gt 0) {
        $current = $pending.Dequeue()
        if (-not $reachable.Add($current)) {
            continue
        }
        foreach ($next in $outbound[$current]) {
            $pending.Enqueue($next)
        }
    }
    $disconnected = @(
        $sourceIds |
            Where-Object { -not $reachable.Contains([string]$_) }
    )
    if ($disconnected.Count -gt 0) {
        throw "Chain '$name' contains findings disconnected from its ordered entry path: $($disconnected -join ', ')."
    }

    $preconditions = @(Get-RequiredValue $chain 'preconditions' "Chain '$name'")
    if ($preconditions.Count -eq 0) {
        throw "Chain '$name' must describe at least one precondition."
    }
    foreach ($precondition in $preconditions) {
        $statement = [string](
            Get-RequiredValue $precondition 'statement' "Chain '$name' precondition")
        $status = [string](
            Get-RequiredValue $precondition 'status' "Chain '$name' precondition '$statement'")
        if ($status -notin @('Verified', 'Inferred', 'Unknown')) {
            throw "Chain '$name' contains unsupported precondition status '$status'."
        }
        Assert-EvidenceReferences `
            -References @(Get-OptionalValue $precondition 'evidenceRefs' @()) `
            -EvidenceIds $evidenceIds `
            -Context "Chain '$name' precondition '$statement'" `
            -AllowEmpty:($status -eq 'Unknown')
    }

    $chainId = 'CHAIN-' + (Get-Sha256(
        'attack-path|' + ($sourceIds -join '>'))).Substring(0, 8)
    if (-not $chainIds.Add($chainId)) {
        throw "Duplicate deterministic chain ID '$chainId'."
    }
    $risk = [string](Get-RequiredValue $chain 'risk' "Chain '$name'")
    Get-SeverityWeight $risk | Out-Null
    $confidence = [string](Get-RequiredValue $chain 'confidence' "Chain '$name'")
    if ($confidence -notin @('High', 'Medium', 'Low')) {
        throw "Chain '$name' has unsupported confidence '$confidence'."
    }

    $normalizedChains.Add([ordered]@{
        chainId = $chainId
        name = $name
        risk = $risk
        confidence = $confidence
        sourceFindingIds = @($sourceIds)
        preconditions = @($preconditions)
        edges = @($edges)
    })
}

$chainSourceIds = @(
    $normalizedChains |
        ForEach-Object { $_.sourceFindingIds } |
        Select-Object -Unique
)
foreach ($findingId in $chainSourceIds) {
    if ($findingMap[[string]$findingId].validationDisposition -eq 'NotReviewed') {
        throw "Chain source finding '$findingId' requires validation adjudication."
    }
}

foreach ($finding in $normalizedFindings) {
    if ($finding.active -and
        $finding.effectiveSeverity -in @('Critical', 'High') -and
        $finding.validationDisposition -eq 'NotReviewed') {
        throw "Critical or High finding '$($finding.findingId)' requires validation adjudication."
    }
}

$componentPriorities = [System.Collections.Generic.List[object]]::new()
foreach ($componentName in @($componentMap.Keys | Sort-Object)) {
    $component = $componentMap[$componentName]
    $componentFindings = @(
        $normalizedFindings |
            Where-Object {
                $_.active -and
                $_.components -contains $componentName
            }
    )
    $base = 0.0
    $domains = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    foreach ($finding in $componentFindings) {
        $base += (Get-SeverityWeight $finding.effectiveSeverity) *
            (Get-ConfidenceWeight $finding.classification)
        foreach ($domain in $finding.domains) {
            $domains.Add([string]$domain) | Out-Null
        }
    }
    $breadth = 1.0
    if ($domains.Count -gt 1) {
        $breadth += [Math]::Min(0.5, 0.1 * ($domains.Count - 1))
    }
    $exposure = [string]$component.exposure
    $priority = [Math]::Round(
        $base * $breadth * (Get-ExposureWeight $exposure),
        1)
    $componentPriorities.Add([ordered]@{
        component = $componentName
        exposure = $exposure
        activeFindingCount = $componentFindings.Count
        distinctDomainCount = $domains.Count
        baseScore = [Math]::Round($base, 1)
        breadthFactor = [Math]::Round($breadth, 2)
        exposureFactor = Get-ExposureWeight $exposure
        priorityScore = $priority
    })
}

$activeFindings = @($normalizedFindings | Where-Object { $_.active })
$summary = [ordered]@{
    totalFindings = $activeFindings.Count
    criticalCount = @($activeFindings | Where-Object { $_.effectiveSeverity -eq 'Critical' }).Count
    highCount = @($activeFindings | Where-Object { $_.effectiveSeverity -eq 'High' }).Count
    mediumCount = @($activeFindings | Where-Object { $_.effectiveSeverity -eq 'Medium' }).Count
    lowCount = @($activeFindings | Where-Object { $_.effectiveSeverity -eq 'Low' }).Count
    informationalCount = @($activeFindings | Where-Object { $_.effectiveSeverity -eq 'Informational' }).Count
    confirmedCount = @($activeFindings | Where-Object { $_.classification -eq 'Confirmed' }).Count
    probableCount = @($activeFindings | Where-Object { $_.classification -eq 'Probable' }).Count
    themeCount = $normalizedThemes.Count
    chainCount = $normalizedChains.Count
    unresolvedValidationCount = 0
}

$output = [ordered]@{
    schemaVersion = $schemaVersion
    serviceName = $serviceName
    sourceRevision = $sourceRevision
    generatedAt = [DateTimeOffset]::UtcNow.ToString('o')
    priorityModel = [ordered]@{
        name = 'crow-v1'
        severityWeights = [ordered]@{
            Critical = 16
            High = 8
            Medium = 4
            Low = 1
            Informational = 0
        }
        confidenceWeights = [ordered]@{
            Confirmed = 1.0
            Probable = 0.5
            Informational = 0.0
        }
        exposureWeights = [ordered]@{
            External = 1.25
            CrossService = 1.15
            Internal = 1.0
        }
        maximumBreadthFactor = 1.5
        severityDerivedFromScore = $false
        chainsIncludedInScore = $false
    }
    summary = $summary
    evidence = @($normalizedEvidence)
    findings = @($normalizedFindings)
    themes = @($normalizedThemes)
    chains = @($normalizedChains)
    componentPriorities = @(
        $componentPriorities |
            Sort-Object -Property @{
                Expression = { [double]$_.priorityScore }
                Descending = $true
            }, @{
                Expression = { [string]$_.component }
                Descending = $false
            }
    )
}
if ($schemaVersion -eq '1.1') {
    $output.stride = @($normalizedStride)
}

$outputDirectory = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
    [System.IO.Directory]::CreateDirectory(
        [System.IO.Path]::GetFullPath($outputDirectory)) | Out-Null
}
[System.IO.File]::WriteAllText(
    [System.IO.Path]::GetFullPath($OutputPath),
    ($output | ConvertTo-Json -Depth 30),
    [System.Text.UTF8Encoding]::new($false))

Write-Output "Crow security synthesis written to $OutputPath"
