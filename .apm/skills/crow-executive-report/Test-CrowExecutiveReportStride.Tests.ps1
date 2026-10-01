[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$validator = Join-Path $PSScriptRoot 'Test-CrowExecutiveReportStride.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    'crow-executive-stride-' + [guid]::NewGuid().ToString('N'))
$docsPath = Join-Path $tempRoot 'docs'
$reportDataPath = Join-Path $docsPath 'report-data.json'
$securityReviewPath = Join-Path $docsPath 'security-review.md'
$synthesisPath = Join-Path $docsPath 'security-review-synthesis.json'
$utf8 = [System.Text.UTF8Encoding]::new($false)

$ratings = [ordered]@{
    component = 'API boundary'
    S = 'High'
    T = 'Medium'
    R = 'Unknown'
    I = 'Low'
    D = 'Medium'
    E = 'N/A'
}
$reportData = [ordered]@{ stride = @($ratings) }
$synthesis = [ordered]@{
    schemaVersion = '1.1'
    serviceName = 'sample'
    sourceRevision = '0123456789abcdef'
    evidence = @([ordered]@{
        id = 'EV-001'
        path = 'src/auth.cs'
        startLine = 10
        endLine = 12
        summary = 'Synthetic source evidence.'
    })
    stride = @([ordered]@{
        component = 'API boundary'
        S = 'High'
        T = 'Medium'
        R = 'Unknown'
        I = 'Low'
        D = 'Medium'
        E = 'N/A'
        evidenceRefs = @('EV-001')
        rationale = 'Risk rationale'
    })
}
$structuredTable = @'
### STRIDE Threat Model Summary
| Component | Spoofing | Tampering | Repudiation | Information Disclosure | Denial of Service | Elevation of Privilege | Evidence IDs | Rationale |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| API boundary | High | Medium | Unknown | Low | Medium | N/A | EV-001 | Risk rationale |
'@.Trim()
$legacyTable = @'
### STRIDE Threat Model Summary
| Component | Spoofing | Tampering | Repudiation | Info Disclosure | DoS | Elevation of Privilege |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| API boundary | High | Medium | Unknown | Low | Medium | N/A |
'@.Trim()

function Write-Json {
    param(
        [string]$Path,
        [object]$Value
    )

    [System.IO.File]::WriteAllText(
        $Path,
        ($Value | ConvertTo-Json -Depth 20),
        $utf8)
}

function Get-ReviewText {
    param(
        [string]$Table,
        [switch]$WithSynthesis
    )

    $frontmatter = @'
---
report_scope: SingleApp
service_name: sample
service_path: .
source_revision: 0123456789abcdef
'@
    if ($WithSynthesis) {
        $frontmatter += "`nsynthesis_artifact: docs/security-review-synthesis.json"
    }
    return @"
$frontmatter
---

## 11. Advanced Security Frameworks
$Table

## 12. Security Finding Synthesis & Assurance
Validated.
"@
}

function Write-Fixture {
    param(
        [object]$Data = $reportData,
        [string]$ReviewText,
        [object]$SynthesisData = $synthesis,
        [switch]$WriteSynthesis,
        [string]$DataPath = $reportDataPath,
        [string]$ReviewPath = $securityReviewPath,
        [string]$SynthPath = $synthesisPath
    )

    Write-Json $DataPath $Data
    [System.IO.File]::WriteAllText($ReviewPath, $ReviewText, $utf8)
    if ($WriteSynthesis) {
        Write-Json $SynthPath $SynthesisData
    }
}

function Invoke-StrideValidator {
    param(
        [switch]$WithSynthesis,
        [string]$DataPath = $reportDataPath,
        [string]$ReviewPath = $securityReviewPath,
        [string]$SynthPath = $synthesisPath
    )

    if ($WithSynthesis) {
        & $validator `
            -ReportDataPath $DataPath `
            -SecurityReviewPath $ReviewPath `
            -SynthesisPath $SynthPath | Out-Null
    }
    else {
        & $validator `
            -ReportDataPath $DataPath `
            -SecurityReviewPath $ReviewPath | Out-Null
    }
}

function Assert-ValidationFails {
    param(
        [string]$Description,
        [switch]$WithSynthesis,
        [string]$DataPath = $reportDataPath,
        [string]$ReviewPath = $securityReviewPath,
        [string]$SynthPath = $synthesisPath
    )

    $failed = $false
    try {
        Invoke-StrideValidator `
            -WithSynthesis:$WithSynthesis `
            -DataPath $DataPath `
            -ReviewPath $ReviewPath `
            -SynthPath $SynthPath
    }
    catch {
        $failed = $true
    }
    if (-not $failed) {
        throw "Expected STRIDE validation failure: $Description."
    }
}

try {
    [System.IO.Directory]::CreateDirectory($docsPath) | Out-Null

    $structuredReview = Get-ReviewText -Table $structuredTable -WithSynthesis
    Write-Fixture -ReviewText $structuredReview -WriteSynthesis
    Invoke-StrideValidator -WithSynthesis

    $incompleteEvidence = [ordered]@{}
    foreach ($property in $synthesis.GetEnumerator()) {
        $incompleteEvidence[$property.Key] = $property.Value
    }
    $incompleteEvidence.evidence = @([ordered]@{ id = 'EV-001' })
    Write-Fixture -ReviewText $structuredReview -SynthesisData $incompleteEvidence -WriteSynthesis
    Assert-ValidationFails 'v1.1 evidence record lacks source details' -WithSynthesis

    $mismatchedData = [ordered]@{ stride = @([ordered]@{ component = 'API boundary'; S = 'Low'; T = 'Medium'; R = 'Unknown'; I = 'Low'; D = 'Medium'; E = 'N/A' }) }
    Write-Fixture -Data $mismatchedData -ReviewText $structuredReview -WriteSynthesis
    Assert-ValidationFails 'report ratings differ from the validated source' -WithSynthesis

    $mismatchedRevision = [ordered]@{}
    foreach ($property in $synthesis.GetEnumerator()) {
        $mismatchedRevision[$property.Key] = $property.Value
    }
    $mismatchedRevision.sourceRevision = 'fedcba9876543210'
    Write-Fixture -ReviewText $structuredReview -SynthesisData $mismatchedRevision -WriteSynthesis
    Assert-ValidationFails 'synthesis source revision differs from the security review' -WithSynthesis

    $wrongHeaderReview = $structuredReview.Replace(
        'Component | Spoofing | Tampering | Repudiation',
        'Component | Tampering | Spoofing | Repudiation')
    Write-Fixture -ReviewText $wrongHeaderReview -WriteSynthesis
    Assert-ValidationFails 'security review STRIDE header is not canonical' -WithSynthesis

    $wrongRatingReview = $structuredReview.Replace(
        '| API boundary | High | Medium | Unknown | Low | Medium | N/A |',
        '| API boundary | Low | Medium | Unknown | Low | Medium | N/A |')
    Write-Fixture -ReviewText $wrongRatingReview -WriteSynthesis
    Assert-ValidationFails 'security review ratings differ from synthesis' -WithSynthesis

    $unresolvedSynthesis = [ordered]@{}
    foreach ($property in $synthesis.GetEnumerator()) {
        $unresolvedSynthesis[$property.Key] = $property.Value
    }
    $unresolvedSynthesis.stride = @([ordered]@{
        component = 'API boundary'
        S = 'High'
        T = 'Medium'
        R = 'Unknown'
        I = 'Low'
        D = 'Medium'
        E = 'N/A'
        evidenceRefs = @('EV-404')
        rationale = 'Risk rationale'
    })
    Write-Fixture -ReviewText $structuredReview -SynthesisData $unresolvedSynthesis -WriteSynthesis
    Assert-ValidationFails 'synthesis evidence reference does not resolve' -WithSynthesis

    $numericReference = [ordered]@{}
    foreach ($property in $synthesis.GetEnumerator()) {
        $numericReference[$property.Key] = $property.Value
    }
    $numericReference.stride = @([ordered]@{
        component = 'API boundary'
        S = 'High'
        T = 'Medium'
        R = 'Unknown'
        I = 'Low'
        D = 'Medium'
        E = 'N/A'
        evidenceRefs = @([int]1)
        rationale = 'Risk rationale'
    })
    Write-Fixture -ReviewText $structuredReview -SynthesisData $numericReference -WriteSynthesis
    Assert-ValidationFails 'synthesis evidence reference is not a string ID' -WithSynthesis

    $duplicateReference = [ordered]@{}
    foreach ($property in $synthesis.GetEnumerator()) {
        $duplicateReference[$property.Key] = $property.Value
    }
    $duplicateReference.stride = @([ordered]@{
        component = 'API boundary'
        S = 'High'
        T = 'Medium'
        R = 'Unknown'
        I = 'Low'
        D = 'Medium'
        E = 'N/A'
        evidenceRefs = @('EV-001', 'EV-001')
        rationale = 'Risk rationale'
    })
    Write-Fixture -ReviewText $structuredReview -SynthesisData $duplicateReference -WriteSynthesis
    Assert-ValidationFails 'synthesis evidence references are duplicated' -WithSynthesis

    $unsafeReference = [ordered]@{}
    foreach ($property in $synthesis.GetEnumerator()) {
        $unsafeReference[$property.Key] = $property.Value
    }
    $unsafeReference.stride = @([ordered]@{
        component = 'API boundary'
        S = 'High'
        T = 'Medium'
        R = 'Unknown'
        I = 'Low'
        D = 'Medium'
        E = 'N/A'
        evidenceRefs = @('EV-001|EV-002')
        rationale = 'Risk rationale'
    })
    Write-Fixture -ReviewText $structuredReview -SynthesisData $unsafeReference -WriteSynthesis
    Assert-ValidationFails 'synthesis evidence ID is unsafe for a Markdown table' -WithSynthesis

    $noMatrixSynthesis = [ordered]@{}
    foreach ($property in $synthesis.GetEnumerator()) {
        if ($property.Key -cne 'stride') {
            $noMatrixSynthesis[$property.Key] = $property.Value
        }
    }
    Write-Fixture -ReviewText $structuredReview -SynthesisData $noMatrixSynthesis -WriteSynthesis
    Assert-ValidationFails 'schemaVersion 1.1 omits its structured matrix' -WithSynthesis

    $legacyReview = Get-ReviewText -Table $legacyTable -WithSynthesis
    $legacySynthesis = [ordered]@{}
    foreach ($property in $synthesis.GetEnumerator()) {
        if ($property.Key -cne 'stride') {
            $legacySynthesis[$property.Key] = $property.Value
        }
    }
    $legacySynthesis.schemaVersion = '1.0'
    Write-Fixture -ReviewText $legacyReview -SynthesisData $legacySynthesis -WriteSynthesis
    Invoke-StrideValidator -WithSynthesis

    Write-Fixture -ReviewText $structuredReview -SynthesisData $legacySynthesis -WriteSynthesis
    Assert-ValidationFails 'schemaVersion 1.0 cannot use the nine-column table' -WithSynthesis

    $legacyWithStride = [ordered]@{}
    foreach ($property in $legacySynthesis.GetEnumerator()) {
        $legacyWithStride[$property.Key] = $property.Value
    }
    $legacyWithStride.stride = @($synthesis.stride)
    Write-Fixture -ReviewText $legacyReview -SynthesisData $legacyWithStride -WriteSynthesis
    Assert-ValidationFails 'schemaVersion 1.0 cannot contain structured STRIDE data' -WithSynthesis

    $legacyReviewWithoutSynthesis = Get-ReviewText -Table $legacyTable
    Write-Fixture -ReviewText $legacyReviewWithoutSynthesis
    Invoke-StrideValidator

    $legacyData = [ordered]@{ stride = @($ratings) }
    $legacyReviewForNewSchema = Get-ReviewText -Table $legacyTable -WithSynthesis
    Write-Fixture -Data $legacyData -ReviewText $legacyReviewForNewSchema -WriteSynthesis
    $newSchemaWithLegacyTable = [ordered]@{}
    foreach ($property in $legacySynthesis.GetEnumerator()) {
        $newSchemaWithLegacyTable[$property.Key] = $property.Value
    }
    $newSchemaWithLegacyTable.schemaVersion = '1.1'
    $newSchemaWithLegacyTable.stride = @($synthesis.stride)
    Write-Fixture -Data $legacyData -ReviewText $legacyReviewForNewSchema -SynthesisData $newSchemaWithLegacyTable -WriteSynthesis
    Assert-ValidationFails 'schemaVersion 1.1 cannot use the abbreviated legacy table' -WithSynthesis

    $monorepoDirectory = Join-Path $docsPath 'sample'
    $otherServiceDirectory = Join-Path $docsPath 'other-service'
    $serviceSourceDirectory = Join-Path $tempRoot 'services\sample'
    [System.IO.Directory]::CreateDirectory($monorepoDirectory) | Out-Null
    [System.IO.Directory]::CreateDirectory($otherServiceDirectory) | Out-Null
    [System.IO.Directory]::CreateDirectory($serviceSourceDirectory) | Out-Null
    $monorepoDataPath = Join-Path $monorepoDirectory 'report-data.json'
    $monorepoReviewPath = Join-Path $monorepoDirectory 'security-review.md'
    $monorepoSynthesisPath = Join-Path $monorepoDirectory 'security-review-synthesis.json'
    $monorepoReview = $structuredReview.Replace(
        'report_scope: SingleApp',
        'report_scope: Monorepo').Replace(
        'service_path: .',
        'service_path: services/sample').Replace(
        'synthesis_artifact: docs/security-review-synthesis.json',
        'synthesis_artifact: docs/sample/security-review-synthesis.json')
    Write-Fixture `
        -ReviewText $monorepoReview `
        -DataPath $monorepoDataPath `
        -ReviewPath $monorepoReviewPath `
        -SynthPath $monorepoSynthesisPath `
        -WriteSynthesis
    Invoke-StrideValidator `
        -WithSynthesis `
        -DataPath $monorepoDataPath `
        -ReviewPath $monorepoReviewPath `
        -SynthPath $monorepoSynthesisPath

    $mismatchedLocationReviewPath = Join-Path $otherServiceDirectory 'security-review.md'
    $mismatchedLocationDataPath = Join-Path $otherServiceDirectory 'report-data.json'
    $mismatchedLocationSynthesisPath = Join-Path $otherServiceDirectory 'security-review-synthesis.json'
    Write-Fixture `
        -ReviewText $monorepoReview `
        -DataPath $mismatchedLocationDataPath `
        -ReviewPath $mismatchedLocationReviewPath `
        -SynthPath $mismatchedLocationSynthesisPath `
        -WriteSynthesis
    Assert-ValidationFails `
        'monorepo review path differs from its declared service name' `
        -WithSynthesis `
        -DataPath $mismatchedLocationDataPath `
        -ReviewPath $mismatchedLocationReviewPath `
        -SynthPath $mismatchedLocationSynthesisPath

    $unsafeServicePathReview = $monorepoReview.Replace(
        'service_path: services/sample',
        'service_path: ../services/sample')
    Write-Fixture `
        -ReviewText $unsafeServicePathReview `
        -DataPath $monorepoDataPath `
        -ReviewPath $monorepoReviewPath `
        -SynthPath $monorepoSynthesisPath `
        -WriteSynthesis
    Assert-ValidationFails `
        'monorepo service path cannot traverse outside the repository' `
        -WithSynthesis `
        -DataPath $monorepoDataPath `
        -ReviewPath $monorepoReviewPath `
        -SynthPath $monorepoSynthesisPath

    Write-Fixture `
        -ReviewText $monorepoReview `
        -DataPath $monorepoDataPath `
        -ReviewPath $monorepoReviewPath `
        -SynthPath $monorepoSynthesisPath `
        -WriteSynthesis
    Assert-ValidationFails `
        'monorepo report data must be adjacent to its scoped review' `
        -WithSynthesis `
        -DataPath $reportDataPath `
        -ReviewPath $monorepoReviewPath `
        -SynthPath $monorepoSynthesisPath

    $emptyData = [ordered]@{ stride = @() }
    Write-Fixture -Data $emptyData -ReviewText $structuredReview -WriteSynthesis
    Assert-ValidationFails 'report data contains no STRIDE rows' -WithSynthesis

    Write-Host 'Executive report source-to-STRIDE validation tests passed.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

exit 0
