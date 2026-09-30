[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot
$synthesisScript = Join-Path $scriptRoot 'New-CrowSecuritySynthesis.ps1'
$reportValidator = Join-Path $scriptRoot 'Test-CrowSecurityReviewOutput.ps1'
$ciScanner = Join-Path $scriptRoot 'Find-CrowSecurityCiGates.ps1'
$powerShellPath = (Get-Process -Id $PID).Path
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    'crow-security-synthesis-' + [guid]::NewGuid().ToString('N'))
$inputPath = Join-Path $tempRoot 'input.json'
$outputPath = Join-Path $tempRoot 'synthesis.json'
$reportPath = Join-Path $tempRoot 'security-review.md'
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Write-Json {
    param(
        [string]$Path,
        [object]$Value
    )
    [System.IO.File]::WriteAllText(
        $Path,
        ($Value | ConvertTo-Json -Depth 30),
        $utf8)
}

function Assert-CommandFails {
    param(
        [string]$Name,
        [string]$Script,
        [string[]]$Arguments
    )

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $powerShellPath -NoProfile -File $Script @Arguments *> $null
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($LASTEXITCODE -eq 0) {
        throw "$Name expected failure."
    }
}

try {
    [System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null
    $input = [ordered]@{
        schemaVersion = '1.0'
        serviceName = 'sample'
        sourceRevision = '0123456789abcdef'
        evidence = @(
            [ordered]@{
                id = 'EV-001'
                path = 'src/auth.cs'
                startLine = 10
                endLine = 12
                summary = 'Synthetic evidence.'
            }
        )
        components = @(
            [ordered]@{ name = 'api'; exposure = 'External' },
            [ordered]@{ name = 'worker'; exposure = 'Internal' }
        )
        findings = @(
            [ordered]@{
                findingId = 'SEC-001'
                title = 'Synthetic high finding'
                severity = 'High'
                classification = 'Confirmed'
                components = @('api')
                domains = @('Authentication')
                validation = [ordered]@{
                    disposition = 'Confirmed'
                    resolution = 'Accepted'
                    rationale = ''
                }
            },
            [ordered]@{
                findingId = 'SEC-002'
                title = 'Synthetic medium finding'
                severity = 'Medium'
                classification = 'Probable'
                components = @('api', 'worker')
                domains = @('Logging')
                validation = [ordered]@{
                    disposition = 'PartiallyConfirmed'
                    resolution = 'Adjusted'
                    adjustedSeverity = 'Low'
                    rationale = 'Synthetic validation adjustment.'
                }
            }
        )
        themes = @(
            [ordered]@{
                themeId = 'THEME-001'
                title = 'Synthetic cross-domain theme'
                sourceFindingIds = @('SEC-001', 'SEC-002')
            }
        )
        chains = @(
            [ordered]@{
                name = 'synthetic-chain'
                risk = 'High'
                confidence = 'Medium'
                sourceFindingIds = @('SEC-001', 'SEC-002')
                edges = @(
                    [ordered]@{
                        from = 'SEC-001'
                        to = 'SEC-002'
                        type = 'contributes-to'
                        evidenceRefs = @('EV-001')
                    }
                )
                preconditions = @(
                    [ordered]@{
                        statement = 'Synthetic verified precondition.'
                        status = 'Verified'
                        evidenceRefs = @('EV-001')
                    }
                )
            }
        )
    }
    Write-Json $inputPath $input
    & $synthesisScript -InputPath $inputPath -OutputPath $outputPath | Out-Null
    $result = [System.IO.File]::ReadAllText($outputPath) | ConvertFrom-Json

    if ($result.summary.totalFindings -ne 2 -or
        $result.summary.highCount -ne 1 -or
        $result.summary.lowCount -ne 1) {
        throw 'Synthesis counts did not apply validation adjustments.'
    }
    if ($result.componentPriorities[0].component -ne 'api' -or
        $result.componentPriorities[0].priorityScore -ne 11.7) {
        throw "Component priority score was not calculated as expected: $($result.componentPriorities[0].component) / $($result.componentPriorities[0].priorityScore)."
    }
    if ($result.chains[0].chainId -notmatch '^CHAIN-[A-F0-9]{8}$') {
        throw 'Deterministic chain ID was not generated.'
    }

    $summary = $result.summary
    $chainId = $result.chains[0].chainId
    $report = @"
---
document_type: security-review
source_revision: $($result.sourceRevision)
total_findings: $($summary.totalFindings)
critical_count: $($summary.criticalCount)
high_count: $($summary.highCount)
medium_count: $($summary.mediumCount)
low_count: $($summary.lowCount)
informational_count: $($summary.informationalCount)
confirmed_count: $($summary.confirmedCount)
probable_count: $($summary.probableCount)
finding_chain_count: $($summary.chainCount)
unresolved_validation_count: $($summary.unresolvedValidationCount)
component_priority_model: crow-v1
---

## 12. Security Finding Synthesis & Assurance
### Architecture handoff
Validated.
### Security control assurance
Assessed.
### Cross-cutting themes
THEME-001
### Evidence-backed attack paths
$chainId
### Component remediation priority
| Rank | Component | Exposure | Active Findings | Domains | Base | Breadth | Exposure Factor | Priority Score |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | api | External | 2 | 2 | 8.5 | 1.1 | 1.25 | 11.7 |
| 2 | worker | Internal | 1 | 1 | 0.5 | 1 | 1 | 0.5 |
### Validation adjudication
| Finding ID | Validation Disposition | Difference Found | Resolution | Effective Severity / Scope | Evidence |
| :--- | :--- | :--- | :--- | :--- | :--- |
| SEC-001 | Confirmed | None | Accepted | High | EV-001 |
| SEC-002 | PartiallyConfirmed | Severity | Adjusted | Low | EV-001 |

## 13. Vulnerability Findings Detail
SEC-001
SEC-002
"@
    [System.IO.File]::WriteAllText($reportPath, $report, $utf8)
    & $reportValidator -ReportPath $reportPath -SynthesisPath $outputPath | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Valid security report did not pass validation.'
    }
    [System.IO.File]::WriteAllText(
        $reportPath,
        $report.Replace(
            '| 1 | api | External | 2 | 2 | 8.5 | 1.1 | 1.25 | 11.7 |',
            '| 1 | api | External | 2 | 2 | 8.5 | 1.1 | 1.25 | 11.8 |'),
        $utf8)
    Assert-CommandFails 'altered component priority row' $reportValidator @(
        '-ReportPath', $reportPath,
        '-SynthesisPath', $outputPath)
    [System.IO.File]::WriteAllText($reportPath, $report, $utf8)

    $input.findings[0].validation.resolution = 'Pending'
    Write-Json $inputPath $input
    Assert-CommandFails 'pending adjudication' $synthesisScript @(
        '-InputPath', $inputPath,
        '-OutputPath', $outputPath)
    $input.findings[0].validation.resolution = 'Accepted'

    $input.chains[0].edges[0].evidenceRefs = @()
    Write-Json $inputPath $input
    Assert-CommandFails 'chain edge without evidence' $synthesisScript @(
        '-InputPath', $inputPath,
        '-OutputPath', $outputPath)
    $input.chains[0].edges[0].evidenceRefs = @('EV-001')

    $input.findings[1].validation.disposition = 'Disputed'
    $input.findings[1].validation.resolution = 'Removed'
    $input.findings[1].validation.rationale = 'Synthetic removal.'
    $input.findings[1].validation.adjustedSeverity = ''
    $savedThemes = $input.themes
    $savedChains = $input.chains
    $input.themes = @()
    $input.chains = @()
    Write-Json $inputPath $input
    & $synthesisScript -InputPath $inputPath -OutputPath $outputPath | Out-Null
    $removedResult = [System.IO.File]::ReadAllText($outputPath) | ConvertFrom-Json
    if ($removedResult.summary.totalFindings -ne 1 -or
        $removedResult.findings[1].active) {
        throw 'Removed adjudication remained active.'
    }

    $input.findings[0].validation.resolution = 'Removed'
    $input.findings[0].validation.rationale = 'Invalid synthetic combination.'
    Write-Json $inputPath $input
    Assert-CommandFails 'confirmed finding cannot be removed' $synthesisScript @(
        '-InputPath', $inputPath,
        '-OutputPath', $outputPath)
    $input.findings[0].validation.resolution = 'Accepted'
    $input.findings[0].validation.rationale = ''

    $input.findings[1].validation.disposition = 'PartiallyConfirmed'
    $input.findings[1].validation.resolution = 'Adjusted'
    $input.findings[1].validation.adjustedSeverity = 'Low'
    $input.findings[1].validation.rationale = 'Synthetic validation adjustment.'
    $input.themes = $savedThemes
    $input.chains = $savedChains
    $input.findings += [ordered]@{
        findingId = 'SEC-003'
        title = 'Synthetic disconnected finding'
        severity = 'Medium'
        classification = 'Confirmed'
        components = @('api')
        domains = @('Authorization')
        validation = [ordered]@{
            disposition = 'Confirmed'
            resolution = 'Accepted'
        }
    }
    $input.chains[0].sourceFindingIds = @('SEC-001', 'SEC-002', 'SEC-003')
    Write-Json $inputPath $input
    Assert-CommandFails 'disconnected chain source' $synthesisScript @(
        '-InputPath', $inputPath,
        '-OutputPath', $outputPath)

    $input.chains[0].sourceFindingIds = @('SEC-001', 'SEC-002')
    $input.chains[0].edges[0].from = 'SEC-002'
    $input.chains[0].edges[0].to = 'SEC-001'
    Write-Json $inputPath $input
    Assert-CommandFails 'reversed chain edge' $synthesisScript @(
        '-InputPath', $inputPath,
        '-OutputPath', $outputPath)

    $input.chains[0].edges[0].from = 'SEC-001'
    $input.chains[0].edges[0].to = 'SEC-002'
    $input.chains[0].edges += [ordered]@{
        from = 'SEC-001'
        to = 'SEC-002'
        type = 'contributes-to'
        evidenceRefs = @('EV-001')
    }
    Write-Json $inputPath $input
    Assert-CommandFails 'duplicate chain edge' $synthesisScript @(
        '-InputPath', $inputPath,
        '-OutputPath', $outputPath)

    $ciRoot = Join-Path $tempRoot 'ci'
    $workflowPath = Join-Path $ciRoot '.github\workflows\ci.yml'
    [System.IO.Directory]::CreateDirectory(
        (Split-Path -Parent $workflowPath)) | Out-Null
    [System.IO.File]::WriteAllText($workflowPath, @'
name: CI
jobs:
  test:
    steps:
      - name: Collect coverage
        run: dotnet test --collect:"XPlat Code Coverage"
      - name: Verify Code Coverage Threshold
        run: Write-Output "Code coverage verified successfully; threshold documented only."
'@, $utf8)
    & git -C $ciRoot init --quiet
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to initialize CI scanner test repository.'
    }
    & git -C $ciRoot add .github/workflows/ci.yml
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to stage CI scanner test workflow.'
    }
    [System.IO.File]::WriteAllText(
        (Join-Path $ciRoot '.github\workflows\untracked.yml'),
        "steps:`n  - run: semgrep --config auto",
        $utf8)
    $ciOutput = Join-Path $tempRoot 'ci-gates.json'
    & $ciScanner -RepoRoot $ciRoot -OutputPath $ciOutput | Out-Null
    $ciResult = [System.IO.File]::ReadAllText($ciOutput) | ConvertFrom-Json
    if (-not $ciResult.gates.coverageCollection.candidateObserved -or
        $ciResult.gates.coverageEnforcement.candidateObserved -or
        $ciResult.gates.sast.candidateObserved -or
        $ciResult.gates.coverageCollection.scope -ne 'TrackedPipelineFiles' -or
        @($ciResult.inspectedFiles).Count -ne 1 -or
        @($ciResult.candidates.noOpCoverage).Count -ne 1) {
        throw "CI gate candidate scan mismatch: collection=$($ciResult.gates.coverageCollection.candidateObserved), enforcement=$($ciResult.gates.coverageEnforcement.candidateObserved), sast=$($ciResult.gates.sast.candidateObserved), scope=$($ciResult.gates.coverageCollection.scope), files=$(@($ciResult.inspectedFiles).Count), candidates=$(@($ciResult.candidates.noOpCoverage).Count)."
    }

    Write-Output 'Crow security synthesis tests passed.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

exit 0
