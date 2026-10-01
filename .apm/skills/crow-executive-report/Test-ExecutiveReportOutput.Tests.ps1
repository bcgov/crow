[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$renderer = Join-Path $root 'render-report.ps1'
$schema = Get-Content (Join-Path $root 'report-data.schema.json') -Raw | ConvertFrom-Json
$data = $schema.example
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    'crow-executive-report-' + [guid]::NewGuid().ToString('N'))
$dataPath = Join-Path $tempRoot 'report-data.json'
$outputPath = Join-Path $tempRoot 'executive-report.html'

function Render-TestReport {
    [System.IO.File]::WriteAllText(
        $dataPath,
        ($data | ConvertTo-Json -Depth 20),
        [System.Text.UTF8Encoding]::new($false))
    & $renderer -DataFile $dataPath -OutputFile $outputPath | Out-Null
    [System.IO.File]::ReadAllText($outputPath)
}

try {
    [System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null
    $legacy = Render-TestReport
    if ($legacy -match 'Systemic Security Risk &amp; Assurance' -or
        $legacy -match '\{\{SECURITY_SYNTHESIS_SECTION\}\}') {
        throw 'Legacy report rendered an unsupported synthesis section.'
    }

    $data | Add-Member -NotePropertyName security_synthesis -NotePropertyValue ([pscustomobject]@{
        source_revision = '0123456789abcdef'
        priority_model = 'crow-v1'
        themes = @(
            [pscustomobject]@{
                id = 'THEME-001'
                implication = 'Repeated &lt;authorization&gt; checks'
                action = 'Unify decisions'
            }
        )
        attack_paths = @(
            [pscustomobject]@{
                id = 'CHAIN-ABCDEF12'
                risk = 'High'
                confidence = 'Medium'
                condition = 'Unknown deployment exposure'
                implication = 'Two controls may fail in sequence'
            }
        )
        component_priorities = @(
            [pscustomobject]@{
                component = 'api'
                active_finding_count = 2
                priority_score = 11.7
                action = 'Repair enforcement first'
            }
        )
        assurance_gaps = @(
            [pscustomobject]@{
                control = '<script>alert(1)</script>'
                status = 'Unknown'
                missing_verification = 'No negative integration test'
                action = 'Test policy boundary'
            }
        )
    })
    $rendered = Render-TestReport
    foreach ($expected in @(
        'Systemic Security Risk &amp; Assurance',
        'CHAIN-ABCDEF12',
        'Unknown deployment exposure',
        'THEME-001',
        '11.7',
        'not severity',
        'No negative integration test',
        '&lt;script&gt;alert(1)&lt;/script&gt;'
    )) {
        if (-not $rendered.Contains($expected)) {
            throw "Synthesis report is missing '$expected'."
        }
    }
    if ($rendered.Contains('<script>alert(1)</script>')) {
        throw 'Synthesis report did not escape untrusted content.'
    }
    $data.security_synthesis.component_priorities[0].priority_score = -1
    $failed = $false
    try { Render-TestReport | Out-Null }
    catch { $failed = $true }
    if (-not $failed) { throw 'Negative component score was accepted.' }

    $data.security_synthesis.component_priorities[0].priority_score = 11.7
    $data.security_synthesis.priority_model = 'CROW-V1'
    $failed = $false
    try { Render-TestReport | Out-Null }
    catch { $failed = $true }
    if (-not $failed) { throw 'Case-mismatched priority model was accepted.' }
    $data.security_synthesis.priority_model = 'crow-v1'

    $data.coverage_pct = $null
    $data.coverage_assessed = $null
    $data.coverage_total = $null
    $data.coverage_gaps = 0
    $rendered = Render-TestReport
    if (-not $rendered.Contains('N/A') -or
        -not $rendered.Contains('coverage cannot be calculated')) {
        throw 'Unknown coverage was represented as measured coverage.'
    }
    Write-Host 'Executive report legacy, synthesis, encoding, and validation tests passed.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

exit 0
