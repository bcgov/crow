[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$validatorPath = Join-Path $PSScriptRoot 'Test-SolutionArchitectureOutput.ps1'
$rendererPath = Join-Path $PSScriptRoot 'Render-SolutionArchitecture.ps1'
$powerShellPath = (Get-Process -Id $PID).Path
$utf8 = [System.Text.UTF8Encoding]::new($false)
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    'crow-solution-architecture-' + [guid]::NewGuid().ToString('N'))

function Invoke-ValidatorTest {
    param(
        [string]$Name,
        [string]$Root,
        [string]$Phase,
        [bool]$ShouldPass
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $result = & $powerShellPath -NoProfile -File $validatorPath `
            -RepoRoot $Root -Phase $Phase 2>&1
        $passed = $LASTEXITCODE -eq 0
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($passed -ne $ShouldPass) {
        throw "$Name expected pass=$ShouldPass but pass=$passed.`n$($result -join [Environment]::NewLine)"
    }
    Write-Host "Passed: $Name"
}

$validDocument = @'
# Solution Architecture: Example

> Status: `Draft`
> Owner: Architecture Owner
> Last reviewed: `2026-09-15`

## 1. Decision Summary
Use a modular monolith. Treat <script>alert("unsafe")</script> as source text.
## 2. Scope and Context
The service supports a bounded workflow.
```mermaid
flowchart LR
    User --> App
```
| Actor | Goal | Primary path | Alternate or assisted path | Accessibility and language considerations |
| :--- | :--- | :--- | :--- | :--- |
| Applicant | Submit a request | Accessible web form | Staff-assisted service | Keyboard and plain-language support |
## 3. Evidence, Assumptions, and Interview Record
| Topic | Evidence or assumption | Status | Owner | Review or decision date |
| :--- | :--- | :--- | :--- | :--- |
| Scope | Confirmed with owner | Confirmed | Owner | 2026-09-15 |
## 4. Quality Attributes and Constraints
| Driver | Target or constraint | Priority | Evidence | Verification |
| :--- | :--- | :--- | :--- | :--- |
| Business criticality | Important service | Must | Owner | Review |
| Uptime | 99.9 percent | Must | Service requirement | Monitor |
| Recovery time objective (RTO) | Four hours | Must | Service requirement | Exercise |
| Recovery point objective (RPO) | One hour | Must | Service requirement | Restore test |
| Data classification | Protected B | Must | Classification review | Security review |
| Data retention and destruction | Seven years then destroy | Must | Records schedule | Audit |
## 5. Proposed Architecture
One deployable application.
| From | Interaction | To | Data or decision | Failure or recovery |
| :--- | :--- | :--- | :--- | :--- |
| User | Submit | Application | Request | Preserve draft and retry |
## 6. Technology Decisions, Defaults, and Fallbacks
| Decision | Preferred default considered | Selected option | Constraint or rationale | Fallback trigger and option | Consequence | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Deployment | Modular monolith | Modular monolith | One team | Independent scale requires services | Added operations | Confirmed |
## 7. Identity and Access
| Population or workload | Authentication and assurance | Authorization and protected resources | Lifecycle and revocation | Outage or assisted path | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Workforce | Government SSO | Resource policy | Offboarding revokes access | Fail closed | Confirmed |
## 8. Data, Integration, and Common Components
| Capability or flow | Owner and system of record | Contract and data purpose | Reuse decision | Failure, reconciliation, and recovery | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Notifications | Product owner | Status updates | Evaluate current common components | Queue and retry | Provisional |
## 9. Deployment and Operations
Health, observability, backup, recovery, support, and rollback are defined.
## 10. Security, Privacy, Accessibility, and Language
Security, privacy, accessibility, Unicode, and language controls are recorded.
## 11. Delivery and Evolution
Delivery is incremental, reversible, compatible, and governed by review gates.
## 12. Decisions, Risks, and Open Questions
| ID | Type | Decision, risk, or question | Owner | Due or review date | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| SA-001 | Decision | Use one deployable application | Owner | 2026-09-15 | Confirmed |
## 13. Sources and Freshness
| Source | Scope used | Authority or owner | Reviewed date | Confidence or limitation |
| :--- | :--- | :--- | :--- | :--- |
| Public guidance | Architecture | Service owner | 2026-09-15 | Current when reviewed |
'@

try {
    New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
    Invoke-ValidatorTest 'pre-write allows missing document' $fixtureRoot 'PreWrite' $true

    $docsPath = Join-Path $fixtureRoot 'docs'
    New-Item -ItemType Directory -Path $docsPath | Out-Null
    [System.IO.File]::WriteAllText(
        (Join-Path $docsPath 'solution-architecture.md'),
        $validDocument,
        $utf8)
    $markdownPath = Join-Path $docsPath 'solution-architecture.md'
    $htmlPath = Join-Path $docsPath 'solution-architecture.html'
    & $rendererPath -RepoRoot $fixtureRoot -MarkdownPath $markdownPath `
        -OutputPath $htmlPath
    Invoke-ValidatorTest 'valid document accepted' $fixtureRoot 'PostWrite' $true
    $renderedHtml = [System.IO.File]::ReadAllText($htmlPath)
    if ($renderedHtml -match '<script>alert') {
        throw 'Renderer did not HTML-encode untrusted source text.'
    }
    if ($renderedHtml.Contains("`r")) {
        throw 'Renderer output contains platform-specific carriage returns.'
    }
    if ($renderedHtml -notmatch '<figure class="flow-view">') {
        throw 'Renderer did not create the semantic architecture flow view.'
    }
    Write-Host 'Passed: renderer output is safe, rich, and newline-stable'

    [System.IO.File]::WriteAllText(
        (Join-Path $docsPath 'solution-architecture.md'),
        '# Solution Architecture: {{SOLUTION_NAME}}',
        $utf8)
    Invoke-ValidatorTest 'incomplete document rejected' $fixtureRoot 'PostWrite' $false

    [System.IO.File]::WriteAllText(
        (Join-Path $docsPath 'solution-architecture.md'),
        $validDocument,
        $utf8)
    & $rendererPath -RepoRoot $fixtureRoot -MarkdownPath $markdownPath `
        -OutputPath $htmlPath
    [System.IO.File]::AppendAllText($htmlPath, '<!-- tampered -->', $utf8)
    Invoke-ValidatorTest 'stale HTML rejected' $fixtureRoot 'PostWrite' $false

    $jsonPath = Join-Path $docsPath 'solution-architecture-data.json'
    & $rendererPath -RepoRoot $fixtureRoot -MarkdownPath $markdownPath `
        -OutputPath $htmlPath `
        -JsonOutputPath $jsonPath
    Invoke-ValidatorTest 'derived JSON accepted' $fixtureRoot 'PostWrite' $true
    [System.IO.File]::WriteAllText(
        $jsonPath,
        ('{"sourceSha256":"' + ('0' * 64) + '","sections":[]}'),
        $utf8)
    Invoke-ValidatorTest 'unrelated JSON rejected' $fixtureRoot 'PostWrite' $false

    Remove-Item -LiteralPath $jsonPath -Force
    $sourceLessDocument = $validDocument -replace (
        '(?ms)(## 13\. Sources and Freshness\r?\n).*'
    ), '$1| Source | Scope used | Authority or owner | Reviewed date | Confidence or limitation |'
    [System.IO.File]::WriteAllText($markdownPath, $sourceLessDocument, $utf8)
    & $rendererPath -RepoRoot $fixtureRoot -MarkdownPath $markdownPath `
        -OutputPath $htmlPath
    Invoke-ValidatorTest 'date outside sources rejected' $fixtureRoot 'PostWrite' $false

    $unresolvedDocument = $validDocument.Replace(
        '> Status: `Draft`',
        '> Status: `Draft / Decision-ready / Approved / Superseded`')
    [System.IO.File]::WriteAllText($markdownPath, $unresolvedDocument, $utf8)
    & $rendererPath -RepoRoot $fixtureRoot -MarkdownPath $markdownPath `
        -OutputPath $htmlPath
    Invoke-ValidatorTest 'unresolved status rejected' $fixtureRoot 'PostWrite' $false

    $blankIdentityDocument = $validDocument.Replace(
        '| Workforce | Government SSO | Resource policy | Offboarding revokes access | Fail closed | Confirmed |',
        '| | | | | | |')
    [System.IO.File]::WriteAllText($markdownPath, $blankIdentityDocument, $utf8)
    & $rendererPath -RepoRoot $fixtureRoot -MarkdownPath $markdownPath `
        -OutputPath $htmlPath
    Invoke-ValidatorTest 'blank required row rejected' $fixtureRoot 'PostWrite' $false

    $blankHomeworkDocument = $validDocument.Replace(
        '| Recovery point objective (RPO) | One hour | Must | Service requirement | Restore test |',
        '| Recovery point objective (RPO) | | | | |')
    [System.IO.File]::WriteAllText($markdownPath, $blankHomeworkDocument, $utf8)
    & $rendererPath -RepoRoot $fixtureRoot -MarkdownPath $markdownPath `
        -OutputPath $htmlPath
    Invoke-ValidatorTest 'blank homework value rejected' $fixtureRoot 'PostWrite' $false

    $placeholderHomeworkDocument = $validDocument.Replace(
        '| Recovery point objective (RPO) | One hour | Must | Service requirement | Restore test |',
        '| Recovery point objective (RPO) | - | Must | Service requirement | Restore test |')
    [System.IO.File]::WriteAllText($markdownPath, $placeholderHomeworkDocument, $utf8)
    & $rendererPath -RepoRoot $fixtureRoot -MarkdownPath $markdownPath `
        -OutputPath $htmlPath
    Invoke-ValidatorTest 'placeholder homework value rejected' $fixtureRoot 'PostWrite' $false

    $outsidePath = Join-Path $fixtureRoot 'outside.html'
    $pathGuarded = $false
    try {
        & $rendererPath -RepoRoot $fixtureRoot -MarkdownPath $markdownPath `
            -OutputPath $outsidePath
    }
    catch {
        $pathGuarded = $true
    }
    if (-not $pathGuarded -or (Test-Path -LiteralPath $outsidePath)) {
        throw 'Renderer accepted an output path outside docs.'
    }
    Write-Host 'Passed: renderer output path guarded'
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}

# Expected failing child validations leave a non-zero native process status.
# Set the suite result explicitly after every assertion and cleanup succeeds.
exit 0
