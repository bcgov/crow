<#
.SYNOPSIS
  Deterministic tests for the Crow business-rule data validator and renderer.

.DESCRIPTION
  Standalone exit-code harness in the style of the other Crow script tests.
  Diagram rendering is exercised with a stub Mermaid CLI, so the tests need no
  network access, no Node.js, and no browser. Exits 0 when every case passes.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$skillRoot = Split-Path -Parent $PSScriptRoot
$rendererPath = Join-Path $PSScriptRoot 'render-business-rules.ps1'
$validatorPath = Join-Path $PSScriptRoot 'Test-BusinessRuleData.ps1'
$exporterPath = Join-Path $PSScriptRoot 'Export-PreviousBusinessRuleData.ps1'
$modulePath = Join-Path $PSScriptRoot 'CrowBusinessRules.psm1'
$schemaPath = Join-Path $skillRoot 'business-rules-data.schema.json'
$examplePath = Join-Path (Join-Path $skillRoot 'resources') 'business-rules-data.example.json'
$powerShellPath = (Get-Process -Id $PID).Path
$utf8 = [System.Text.UTF8Encoding]::new($false)
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    'crow-business-rules-tests-' + [guid]::NewGuid().ToString('N'))
$passed = 0

Import-Module $modulePath -Force
$businessRulesModule = Get-Module 'CrowBusinessRules'

function Assert-Condition {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )

    if (-not $Condition) { throw $Message }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Expected,
        [Parameter(Mandatory)][string]$Message
    )

    if (-not $Text.Contains($Expected)) {
        throw "$Message (expected to find '$Expected')."
    }
}

function Assert-NotContains {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Unexpected,
        [Parameter(Mandatory)][string]$Message
    )

    if ($Text.Contains($Unexpected)) {
        throw "$Message (unexpectedly found '$Unexpected')."
    }
}

function New-CaseDirectory {
    param([Parameter(Mandatory)][string]$Name)

    $path = Join-Path $fixtureRoot $Name
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Write-StubCli {
    <#
    .SYNOPSIS
      Writes a Node-free stand-in for the Mermaid CLI.

    .DESCRIPTION
      The stub reads the '--input' diagram, extracts its labels, and echoes them
      into <text>/<tspan> nodes after XML-escaping them, the way mmdc carries
      label text. Ordinary label text such as 'Data: pending' therefore reaches
      Test-CrowRenderedSvg instead of a fixed 'node' string. The malicious modes
      inject an active construct into markup - a script element, a data: URL, a
      javascript: URL, an event handler attribute, or a script hidden behind a
      comment terminator, an unquoted attribute value, a re-armed quote inside
      an unquoted value, a solidus that does not self-close a raw-text element,
      or a browser-valid raw-text end tag such as '</style/>' or '</style foo>'
      that ends the raw text before the injected markup - never into text.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [ValidateSet('valid', 'malicious', 'malicious-data-url',
            'malicious-javascript-url', 'malicious-event-attribute',
            'malicious-comment-terminator', 'malicious-comment-body',
            'malicious-unquoted-value', 'malicious-unquoted-requote',
            'malicious-unquoted-requote-handler',
            'malicious-solidus-style', 'malicious-solidus-script',
            'malicious-end-tag-solidus-style', 'malicious-end-tag-attribute-style',
            'malicious-end-tag-solidus-script', 'malicious-end-tag-attribute-script',
            'failing')]
        [string]$Mode = 'valid'
    )

    $body = @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
$inputPath = $null
$outputPath = $null
for ($index = 0; $index -lt $Arguments.Count; $index++) {
    if ($Arguments[$index] -eq '--input') { $inputPath = $Arguments[$index + 1] }
    if ($Arguments[$index] -eq '--output') { $outputPath = $Arguments[$index + 1] }
}
if (-not $outputPath) { exit 2 }
$mode = 'MODE'
if ($mode -eq 'failing') { exit 3 }
if (-not $inputPath -or -not (Test-Path -LiteralPath $inputPath)) { exit 4 }

# Echo the diagram's own labels, escaped, into text nodes.
$source = [System.IO.File]::ReadAllText($inputPath)
$labels = New-Object 'System.Collections.Generic.List[string]'
foreach ($pattern in @(
        '\[([^\[\]]+)\]', '\(([^()]+)\)', '\{([^{}]+)\}',
        '(?:-->|->>|->|==>)\s*([^\r\n\[\]{}():;|>-]+)')) {
    foreach ($match in [regex]::Matches($source, $pattern)) {
        $label = $match.Groups[1].Value.Trim()
        if ($label -and -not $labels.Contains($label)) { $labels.Add($label) }
    }
}
if ($labels.Count -eq 0) { $labels.Add('node') }

$labelMarkup = ''
foreach ($label in $labels) {
    $labelMarkup += '<text x="1" y="9" class="nodeLabel"><tspan class="text-outer-tspan" x="0" dy="1.1em">' +
        '<tspan class="text-inner-tspan">' + [System.Net.WebUtility]::HtmlEncode($label) +
        '</tspan></tspan></text>'
}

$payload = '<g class="node"><circle cx="5" cy="5" r="4"/>' + $labelMarkup + '</g>'
switch ($mode) {
    'malicious' { $payload = '<script>alert(1)</script>' + $payload }
    'malicious-data-url' { $payload = '<a xlink:href="data:text/html;base64,PHN2Zz48L3N2Zz4=">' + $payload + '</a>' }
    'malicious-javascript-url' { $payload = '<a href="javascript:alert(1)">' + $payload + '</a>' }
    'malicious-event-attribute' { $payload = '<g onload="alert(1)">' + $payload + '</g>' }
    'malicious-comment-terminator' { $payload = '<!-- note --!><script>alert(1)</script><!-- end -->' + $payload }
    'malicious-comment-body' { $payload = '<!-- note -- hidden --><script>alert(1)</script>' + $payload }
    'malicious-unquoted-value' { $payload = "<text data-x=a'b><script>alert(1)</script>'</text>" + $payload }
    'malicious-unquoted-requote' { $payload = '<text data-x=a="><script>alert(1)</script>"></text>' + $payload }
    'malicious-unquoted-requote-handler' { $payload = '<g data-x=a=''><g onload=''alert(1)''/>''></g>' + $payload }
    'malicious-solidus-style' { $payload = '<style/>@import url(http://evil.example/x.css);</style>' + $payload }
    'malicious-solidus-script' { $payload = '<script/>alert(1)</script>' + $payload }
    'malicious-end-tag-solidus-style' { $payload = '<style>.a{fill:#fff}</style/><script>alert(1)</script></style>' + $payload }
    'malicious-end-tag-attribute-style' { $payload = '<style>.a{fill:#fff}</style foo><image href="http://evil.example/x.png"/></style>' + $payload }
    'malicious-end-tag-solidus-script' { $payload = '<script>var a=1;</script/><g onload="alert(1)"/></script>' + $payload }
    'malicious-end-tag-attribute-script' { $payload = '<script>var a=1;</script foo><script>alert(1)</script></script>' + $payload }
}
$svg = '<svg id="graph" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="120" height="60" aria-roledescription="flowchart">' +
    '<defs><marker id="arrowhead"><path d="M0,0 L6,3 L0,6 z"/></marker></defs>' +
    '<style>#graph .node { fill: #ffffff; }</style>' +
    '<line x1="0" y1="0" x2="9" y2="9" marker-end="url(#arrowhead)"/>' +
    $payload + '</svg>'
[System.IO.File]::WriteAllText($outputPath, $svg, [System.Text.UTF8Encoding]::new($false))
exit 0
'@
    $body = $body.Replace("'MODE'", "'$Mode'")
    [System.IO.File]::WriteAllText($Path, $body, $utf8)
}

function New-BaseData {
    return [ordered]@{
        schema_version        = '1.0'
        application           = [ordered]@{
            name       = 'Permit Intake Service'
            acronym    = 'PIS'
            scope      = 'One service: the permit intake API.'
            repository = 'example-org/permit-intake-service'
            commit     = '0f3c1b2'
        }
        generated             = '2026-01-15'
        documentation_sources = @(
            [ordered]@{
                id       = 'DOC-1'
                title    = 'Permit intake user guide'
                kind     = 'guide'
                status   = 'available'
                location = 'docs/intake-user-guide.md'
            },
            [ordered]@{
                id       = 'DOC-2'
                title    = 'Intake officer training deck'
                kind     = 'training'
                status   = 'unavailable'
                location = 'Referenced by the intake team; no copy was supplied.'
            }
        )
        documentation_gap     = [ordered]@{
            present         = $true
            summary         = 'The intake officer training deck could not be inspected.'
            coverage_impact = 'Reconciliation coverage is reduced for training-only rules.'
        }
        facet_groups          = @(
            [ordered]@{
                id     = 'domain'
                label  = 'Domain'
                facets = @(
                    [ordered]@{ id = 'domain.eligibility'; label = 'Eligibility'; description = 'Decides who may proceed.' },
                    [ordered]@{ id = 'domain.fees'; label = 'Fees' }
                )
            },
            [ordered]@{
                id     = 'kind'
                label  = 'Rule kind'
                facets = @(
                    [ordered]@{ id = 'kind.validation'; label = 'Validation' },
                    [ordered]@{ id = 'kind.calculation'; label = 'Calculation' }
                )
            }
        )
        rules                 = @(
            [ordered]@{
                id                 = 'BR-0001'
                title              = 'Applicants must be 19 or older'
                status             = 'active'
                category           = 'validation'
                statement          = 'Submissions from applicants under 19 are rejected.'
                facets             = @('domain.eligibility', 'kind.validation')
                citations          = @(
                    [ordered]@{
                        path   = 'src/Intake/ApplicantAgeRule.cs'
                        symbol = 'ApplicantAgeRule.Validate'
                        commit = '0f3c1b2'
                        line   = 34
                    }
                )
                documentation_refs = @('DOC-1')
                match_notes        = @(
                    [ordered]@{ facet = 'domain.eligibility'; reason = 'Blocks submission before processing.' }
                )
                reconciliation     = [ordered]@{
                    classification = 'aligned'
                    note           = 'Guide and validator agree.'
                }
            },
            [ordered]@{
                id                 = 'BR-0002'
                title              = 'Base fee uses permit class and duration'
                status             = 'active'
                category           = 'calculation'
                statement          = 'The base fee is the class rate multiplied by the duration in months.'
                facets             = @('domain.fees', 'kind.calculation')
                citations          = @(
                    [ordered]@{
                        path   = 'src/Intake/FeeCalculator.cs'
                        symbol = 'FeeCalculator.CalculateBaseFee'
                        commit = '0f3c1b2'
                    }
                )
                documentation_refs = @()
                reconciliation     = [ordered]@{
                    classification = 'implemented-only'
                    note           = 'No available document describes the rounding mode.'
                }
            },
            [ordered]@{
                id                 = 'BR-0003'
                title              = 'Paper submissions created a review queue entry'
                status             = 'retired'
                category           = 'workflow'
                statement          = 'Paper submissions once created a manual review queue entry.'
                facets             = @('domain.eligibility')
                citations          = @(
                    [ordered]@{
                        path   = 'src/Intake/Legacy/PaperSubmissionQueue.cs'
                        symbol = 'PaperSubmissionQueue.Enqueue'
                        commit = '9a4d7e1'
                    }
                )
                documentation_refs = @()
                reconciliation     = [ordered]@{
                    classification = 'implemented-only'
                    note           = 'The implementation was removed before the reviewed commit.'
                }
                retirement         = [ordered]@{
                    retired_on = '2026-01-15'
                    reason     = 'Paper submissions were discontinued.'
                }
            }
        )
        diagrams              = @(
            [ordered]@{
                id          = 'intake-decision'
                title       = 'Intake decision flow'
                description = 'Order in which intake rules are applied.'
                mermaid     = "flowchart TD`n  A[Submission] --> B[Validate age]`n  B --> C[Calculate fee]"
                rule_refs   = @('BR-0001', 'BR-0002')
            },
            [ordered]@{
                id          = 'application-lifecycle'
                title       = 'Application lifecycle states'
                description = 'States an application moves through.'
                mermaid     = "stateDiagram-v2`n  [*] --> Draft`n  Draft --> Submitted"
                rule_refs   = @('BR-0003')
            }
        )
        open_questions        = @('Which role may reopen a withdrawn application?')
    }
}

function Save-DataFile {
    param(
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][object]$Data
    )

    $path = Join-Path $Directory 'business-rules-data.json'
    [System.IO.File]::WriteAllText($path, ($Data | ConvertTo-Json -Depth 12), $utf8)
    return $path
}

function Invoke-Renderer {
    param(
        [Parameter(Mandatory)][string]$Directory,
        [string]$StubMode = 'valid',
        [string]$OverrideCliPath,
        [switch]$DiscoverCliOnPath,
        [string]$PreviousDataPath,
        [switch]$AllowRetiredRuleReactivation
    )

    $dataPath = Join-Path $Directory 'business-rules-data.json'
    $arguments = @('-NoProfile', '-File', $rendererPath, '-DataFile', $dataPath)
    if (-not $DiscoverCliOnPath) {
        $cliPath = $OverrideCliPath
        if (-not $cliPath) {
            $cliPath = Join-Path $Directory 'stub-mmdc.ps1'
            Write-StubCli -Path $cliPath -Mode $StubMode
        }
        $arguments += @('-MermaidCliPath', $cliPath)
    }
    if ($PreviousDataPath) { $arguments += @('-PreviousDataFile', $PreviousDataPath) }
    if ($AllowRetiredRuleReactivation) { $arguments += '-AllowRetiredRuleReactivation' }

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $powerShellPath @arguments 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    return [pscustomobject]@{
        ExitCode     = $exitCode
        Output       = [regex]::Replace([string]$output, '\s+', ' ')
        MarkdownPath = Join-Path $Directory 'business-rules.md'
        HtmlPath     = Join-Path $Directory 'business-rules.html'
    }
}

function Invoke-RendererWithBundledAsset {
    param(
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][ValidateSet('business-rules.css', 'business-rules.js')]
        [string]$AssetName,
        [Parameter(Mandatory)][string]$AssetContent
    )

    $copiedSkillRoot = Join-Path $Directory 'crow-business-rules'
    Copy-Item -LiteralPath $skillRoot -Destination $copiedSkillRoot -Recurse

    $copiedAssetPath = Join-Path (Join-Path $copiedSkillRoot 'assets') $AssetName
    [System.IO.File]::WriteAllText($copiedAssetPath, $AssetContent, $utf8)

    $outputDirectory = Join-Path $Directory 'output'
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    $dataPath = Save-DataFile -Directory $outputDirectory -Data (New-BaseData)
    $stubPath = Join-Path $Directory 'stub-mmdc.ps1'
    Write-StubCli -Path $stubPath

    $copiedRendererPath = Join-Path (Join-Path $copiedSkillRoot 'scripts') 'render-business-rules.ps1'
    $arguments = @(
        '-NoProfile', '-File', $copiedRendererPath,
        '-DataFile', $dataPath,
        '-MermaidCliPath', $stubPath
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $powerShellPath @arguments 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    return [pscustomobject]@{
        ExitCode     = $exitCode
        Output       = [regex]::Replace([string]$output, '\s+', ' ')
        MarkdownPath = Join-Path $outputDirectory 'business-rules.md'
        HtmlPath     = Join-Path $outputDirectory 'business-rules.html'
    }
}

function Invoke-Validator {
    param(
        [Parameter(Mandatory)][string]$DataPath,
        [string]$PreviousDataPath,
        [switch]$AllowRetiredRuleReactivation
    )

    $arguments = @('-NoProfile', '-File', $validatorPath, '-DataFile', $DataPath)
    if ($PreviousDataPath) { $arguments += @('-PreviousDataFile', $PreviousDataPath) }
    if ($AllowRetiredRuleReactivation) { $arguments += '-AllowRetiredRuleReactivation' }

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $powerShellPath @arguments 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = [regex]::Replace([string]$output, '\s+', ' ')
    }
}

function New-PathDiscoveryStub {
    <#
    .SYNOPSIS
      Reproduces npm's Windows shim layout: a PowerShell wrapper (mmdc.ps1) that
      PowerShell resolves first, next to the executable the renderer must find.
    #>
    param([Parameter(Mandatory)][string]$Directory)

    $decoyPath = Join-Path $Directory 'mmdc.ps1'
    [System.IO.File]::WriteAllText(
        $decoyPath,
        "Write-Error 'The mmdc.ps1 shim must never be selected by PATH discovery.'`r`nexit 9`r`n",
        $utf8)

    $stubPath = Join-Path $Directory 'stub-mmdc.ps1'
    Write-StubCli -Path $stubPath -Mode 'valid'

    if ($env:OS -eq 'Windows_NT') {
        $executablePath = Join-Path $Directory 'mmdc.cmd'
        [System.IO.File]::WriteAllText(
            $executablePath,
            "@echo off`r`n`"$powerShellPath`" -NoProfile -File `"$stubPath`" %*`r`n",
            $utf8)
    }
    else {
        $executablePath = Join-Path $Directory 'mmdc'
        [System.IO.File]::WriteAllText(
            $executablePath,
            "#!/bin/sh`nexec `"$powerShellPath`" -NoProfile -File `"$stubPath`" `"`$@`"`n",
            $utf8)
        & chmod '+x' $executablePath
        if ($LASTEXITCODE -ne 0) { throw 'Unable to mark the stub Mermaid CLI executable.' }
    }

    return $executablePath
}

function New-ProbeHtml {
    <#
    .SYNOPSIS
      Wraps a body fragment in the structure the report template produces: one
      style element and exactly one attribute-free inline script block.
    #>
    param(
        [string]$Body = '<p>Report body.</p>',
        [string]$Script = 'var total = 1;',
        [string]$Style = '.rule { color: #000; }'
    )

    return '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><title>Report</title>' +
    "<style>$Style</style></head><body>$Body<script>$Script</script></body></html>"
}

function New-StubGit {
    <#
    .SYNOPSIS
      Writes a Node-free and git-free stand-in that emits fixed bytes on stdout.

    .DESCRIPTION
      The payload is written as raw bytes to the standard output stream, so the
      extraction helper is exercised on exactly the bytes a real 'git show'
      would produce, including non-ASCII UTF-8 content.
    #>
    param(
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Payload,
        [int]$ExitCode = 0
    )

    $body = @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
$exitCode = EXIT_CODE
if ($exitCode -ne 0) { exit $exitCode }
$bytes = [System.Convert]::FromBase64String('PAYLOAD')
$stream = [Console]::OpenStandardOutput()
$stream.Write($bytes, 0, $bytes.Length)
$stream.Flush()
exit 0
'@
    $body = $body.Replace('EXIT_CODE', [string]$ExitCode).Replace(
        'PAYLOAD',
        [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Payload)))

    $scriptPath = Join-Path $Directory 'stub-git-body.ps1'
    [System.IO.File]::WriteAllText($scriptPath, $body, $utf8)

    if ($env:OS -eq 'Windows_NT') {
        $executablePath = Join-Path $Directory 'stub-git.cmd'
        [System.IO.File]::WriteAllText(
            $executablePath,
            "@echo off`r`n`"$powerShellPath`" -NoProfile -File `"$scriptPath`" %*`r`n",
            $utf8)
    }
    else {
        $executablePath = Join-Path $Directory 'stub-git'
        [System.IO.File]::WriteAllText(
            $executablePath,
            "#!/bin/sh`nexec `"$powerShellPath`" -NoProfile -File `"$scriptPath`" `"`$@`"`n",
            $utf8)
        & chmod '+x' $executablePath
        if ($LASTEXITCODE -ne 0) { throw 'Unable to mark the stub git executable.' }
    }

    return $executablePath
}

function Invoke-Exporter {
    param(
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$GitPath,
        [string]$RepositoryRoot
    )

    if (-not $RepositoryRoot) { $RepositoryRoot = Split-Path -Parent $Destination }
    $arguments = @(
        '-NoProfile', '-File', $exporterPath,
        '-Destination', $Destination,
        '-GitPath', $GitPath,
        '-RepositoryRoot', $RepositoryRoot)

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $powerShellPath @arguments 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = [regex]::Replace([string]$output, '\s+', ' ')
    }
}

function Get-TemporaryArtifact {
    <#
    .SYNOPSIS
      Returns the staging and backup files a publication step must never leave
      behind.
    #>
    param([Parameter(Mandatory)][string]$Directory)

    return @(Get-ChildItem -LiteralPath $Directory -File |
        Where-Object { $_.Name -like '*.tmp' -or $_.Name -like '*.bak' })
}

function Assert-NoOutputFiles {
    param([Parameter(Mandatory)][object]$Result, [Parameter(Mandatory)][string]$Name)

    Assert-Condition (-not (Test-Path -LiteralPath $Result.MarkdownPath)) `
        "$Name wrote a partial Markdown file. Output: $($Result.Output)"
    Assert-Condition (-not (Test-Path -LiteralPath $Result.HtmlPath)) `
        "$Name wrote a partial HTML file. Output: $($Result.Output)"
}

function Invoke-FailureCase {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Mutate,
        [string]$StubMode = 'valid',
        [string]$ExpectedMessage
    )

    $directory = New-CaseDirectory $Name
    $data = New-BaseData
    & $Mutate $data
    Save-DataFile -Directory $directory -Data $data | Out-Null
    $result = Invoke-Renderer -Directory $directory -StubMode $StubMode

    Assert-Condition ($result.ExitCode -ne 0) "$Name should have failed. Output: $($result.Output)"
    Assert-NoOutputFiles -Result $result -Name $Name
    if ($ExpectedMessage) {
        Assert-Contains -Text $result.Output -Expected $ExpectedMessage `
            -Message "$Name did not report the expected failure"
    }
    Write-Host "Passed: $Name"
    $script:passed++
}

try {
    New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null

    # -----------------------------------------------------------------
    # 1. Valid render, accessible facet state, and self-contained output
    # -----------------------------------------------------------------
    $directory = New-CaseDirectory 'valid-render'
    Save-DataFile -Directory $directory -Data (New-BaseData) | Out-Null
    $result = Invoke-Renderer -Directory $directory
    Assert-Condition ($result.ExitCode -eq 0) "Valid render failed. Output: $($result.Output)"
    Assert-Condition (Test-Path -LiteralPath $result.MarkdownPath) 'Markdown output is missing.'
    Assert-Condition (Test-Path -LiteralPath $result.HtmlPath) 'HTML output is missing.'

    $markdown = [System.IO.File]::ReadAllText($result.MarkdownPath)
    $html = [System.IO.File]::ReadAllText($result.HtmlPath)

    foreach ($expected in @(
            'BR-0001', 'BR-0002', 'BR-0003',
            'src/Intake/ApplicantAgeRule.cs',
            'Documentation gap',
            '```mermaid',
            'implemented-only',
            'retired rule identifiers are never reused')) {
        Assert-Contains -Text $markdown -Expected $expected -Message 'Markdown output is incomplete'
    }
    Assert-NotContains -Text $markdown -Unexpected '{{' -Message 'Markdown output has unresolved placeholders'

    foreach ($expected in @(
            'aria-live="polite"',
            'role="status"',
            'data-facets="domain.eligibility kind.validation"',
            'data-facet="domain.eligibility"',
            'aria-expanded="true"',
            '<noscript>',
            'id="filter-reset"',
            'type="reset"',
            'id="no-results"',
            'class="match-reason"',
            'tabindex="-1"',
            '<form id="facet-filter" class="facet-filter" hidden>',
            'Blocks submission before processing.',
            'Documentation gap',
            'Match reasons<span class="visually-hidden"> for BR-0001</span>',
            'Match reasons<span class="visually-hidden"> for BR-0002</span>',
            '.visually-hidden {',
            '<svg')) {
        Assert-Contains -Text $html -Expected $expected -Message 'HTML output is incomplete'
    }
    foreach ($unexpected in @('{{', '<link', '@import', 'href="http://', 'integrity=')) {
        Assert-NotContains -Text $html -Unexpected $unexpected -Message 'HTML output is not self-contained'
    }
    Assert-Contains -Text $html -Expected '(function () {' `
        -Message 'The bundled behaviour script was not injected into the script element'
    Assert-Contains -Text $html -Expected ':root {' `
        -Message 'The bundled stylesheet was not injected into the style element'
    Assert-NotContains -Text $html -Unexpected '/*{{' `
        -Message 'HTML output still contains a comment-wrapped injection point'
    Assert-Condition (-not ([regex]::IsMatch($html, '(?i)\ssrc\s*='))) `
        'HTML output loads an external subresource.'
    Assert-Condition ([System.IO.File]::ReadAllBytes($result.HtmlPath)[0] -ne 239) `
        'HTML output was written with a UTF-8 BOM.'
    Assert-NotContains -Text $html -Unexpected "`r`n" -Message 'HTML output uses platform-specific line endings'
    Write-Host 'Passed: renders a valid report with accessible facet state and self-contained output'
    $passed++

    # -----------------------------------------------------------------
    # 2. Two diagrams inline without identifier collisions
    # -----------------------------------------------------------------
    $identifiers = @([regex]::Matches($html, '\sid="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    $duplicates = @($identifiers | Group-Object | Where-Object { $_.Count -gt 1 })
    Assert-Condition ($duplicates.Count -eq 0) `
        "Rendered HTML contains duplicate element ids: $(($duplicates | ForEach-Object { $_.Name }) -join ', ')"
    Assert-Condition ((@([regex]::Matches($html, '<svg')).Count) -eq 2) `
        'Both diagrams should be inlined as SVG.'
    foreach ($expected in @(
            'id="br-intake-decision-graph"',
            'id="br-intake-decision-arrowhead"',
            'id="br-application-lifecycle-graph"',
            'id="br-application-lifecycle-arrowhead"',
            'url(#br-intake-decision-arrowhead)',
            'url(#br-application-lifecycle-arrowhead)')) {
        Assert-Contains -Text $html -Expected $expected -Message 'Diagram identifiers were not made unique'
    }
    Write-Host 'Passed: multiple diagrams inline with unique identifiers'
    $passed++

    # -----------------------------------------------------------------
    # 3. Per-context escaping
    # -----------------------------------------------------------------
    $directory = New-CaseDirectory 'escaping'
    $data = New-BaseData
    $data.rules[0].title = 'Reject <script>alert(1)</script> | pipe'
    $data.rules[0].statement = 'Escaping check for <b>bold</b> & "quotes" | pipes.'
    Save-DataFile -Directory $directory -Data $data | Out-Null
    $result = Invoke-Renderer -Directory $directory
    Assert-Condition ($result.ExitCode -eq 0) "Escaping render failed. Output: $($result.Output)"
    $markdown = [System.IO.File]::ReadAllText($result.MarkdownPath)
    $html = [System.IO.File]::ReadAllText($result.HtmlPath)
    Assert-NotContains -Text $html -Unexpected '<script>alert(1)</script>' -Message 'HTML escaping failed'
    Assert-Contains -Text $html -Expected '&lt;script&gt;alert(1)&lt;/script&gt;' -Message 'HTML escaping failed'
    Assert-Contains -Text $html -Expected '&amp;' -Message 'HTML escaping failed'
    Assert-NotContains -Text $markdown -Unexpected '<script>' -Message 'Markdown escaping failed'
    Assert-Contains -Text $markdown -Expected '\<script\>' -Message 'Markdown escaping failed'
    Assert-Contains -Text $markdown -Expected '\|' -Message 'Markdown table escaping failed'
    Write-Host 'Passed: escapes HTML and Markdown per context'
    $passed++

    # -----------------------------------------------------------------
    # 3b. Self-contained checks reject inline handlers and remote assets
    # -----------------------------------------------------------------
    $selfContainedErrors = New-Object 'System.Collections.Generic.List[string]'
    Test-CrowSelfContainedHtml -Html '<button onclick="run()">Go</button>' -Errors $selfContainedErrors
    Assert-Condition ($selfContainedErrors.Count -gt 0) `
        'An inline event handler should be rejected.'
    $selfContainedErrors = New-Object 'System.Collections.Generic.List[string]'
    Test-CrowSelfContainedHtml -Html '<a href="data:text/html,x">x</a>' -Errors $selfContainedErrors
    Assert-Condition ($selfContainedErrors.Count -gt 0) 'A data: link should be rejected.'
    $selfContainedErrors = New-Object 'System.Collections.Generic.List[string]'
    Test-CrowSelfContainedHtml -Html $html -Errors $selfContainedErrors
    Assert-Condition ($selfContainedErrors.Count -eq 0) `
        "The rendered report should pass the self-contained check: $($selfContainedErrors -join '; ')"
    Write-Host 'Passed: self-contained check rejects inline handlers and unsafe links'
    $passed++

    # -----------------------------------------------------------------
    # 3c. Bundled raw-text assets cannot close their containing elements
    # -----------------------------------------------------------------
    foreach ($assetCase in @(
            @{
                Name            = 'css-style-closing-sequence'
                AssetName       = 'business-rules.css'
                Content         = 'body{color:#111}</style><p>escaped style</p>'
                ExpectedMessage = 'style-closing sequence'
            },
            @{
                Name            = 'css-style-solidus-closing-sequence'
                AssetName       = 'business-rules.css'
                Content         = 'body{color:#111}</style/><p>escaped style</p>'
                ExpectedMessage = 'style-closing sequence'
            },
            @{
                Name            = 'css-style-attribute-closing-sequence'
                AssetName       = 'business-rules.css'
                Content         = 'body{color:#111}</style foo><p>escaped style</p>'
                ExpectedMessage = 'style-closing sequence'
            },
            @{
                Name            = 'javascript-script-closing-sequence'
                AssetName       = 'business-rules.js'
                Content         = 'const value = "</script><p>escaped script</p>";'
                ExpectedMessage = 'script-closing sequence'
            },
            @{
                Name            = 'javascript-script-solidus-closing-sequence'
                AssetName       = 'business-rules.js'
                Content         = 'const value = "</script/><p>escaped script</p>";'
                ExpectedMessage = 'script-closing sequence'
            })) {
        $directory = New-CaseDirectory $assetCase.Name
        $result = Invoke-RendererWithBundledAsset -Directory $directory `
            -AssetName $assetCase.AssetName -AssetContent $assetCase.Content
        Assert-Condition ($result.ExitCode -ne 0) `
            "Bundled asset '$($assetCase.AssetName)' was allowed to close its containing element."
        Assert-Contains -Text $result.Output -Expected $assetCase.ExpectedMessage `
            -Message "Bundled asset '$($assetCase.AssetName)' failed for the wrong reason"
        Assert-Condition (-not (Test-Path -LiteralPath $result.MarkdownPath)) `
            "Bundled asset '$($assetCase.AssetName)' left partial Markdown output."
        Assert-Condition (-not (Test-Path -LiteralPath $result.HtmlPath)) `
            "Bundled asset '$($assetCase.AssetName)' left partial HTML output."
    }

    $directory = New-CaseDirectory 'javascript-script-near-match'
    $result = Invoke-RendererWithBundledAsset -Directory $directory `
        -AssetName 'business-rules.js' -AssetContent 'const value = "</scriptfoo";'
    Assert-Condition ($result.ExitCode -eq 0) `
        "A benign script end-tag near-match was rejected. Output: $($result.Output)"
    Assert-Condition (Test-Path -LiteralPath $result.MarkdownPath) `
        'The benign bundled JavaScript case did not publish Markdown output.'
    Assert-Condition (Test-Path -LiteralPath $result.HtmlPath) `
        'The benign bundled JavaScript case did not publish HTML output.'
    Write-Host 'Passed: bundled CSS and JavaScript cannot close their containing raw-text elements'
    $passed++

    # -----------------------------------------------------------------
    # 4-10. Validation failures leave no output
    # -----------------------------------------------------------------
    Invoke-FailureCase -Name 'unsupported-property' -ExpectedMessage "unsupported property 'url'" -Mutate {
        param($data)
        $data.documentation_sources[0].url = 'https://example.org/intake-guide'
    }

    Invoke-FailureCase -Name 'forbidden-mermaid-directive' -ExpectedMessage 'init directives' -Mutate {
        param($data)
        $data.diagrams[0].mermaid = "%%{init: {'theme':'dark'}}%%`nflowchart TD`n  A --> B"
    }

    Invoke-FailureCase -Name 'forbidden-mermaid-interaction' -ExpectedMessage 'click interactions' -Mutate {
        param($data)
        $data.diagrams[0].mermaid = "flowchart TD`n  A --> B`nclick A callback"
    }

    Invoke-FailureCase -Name 'duplicate-rule-ids' -ExpectedMessage 'duplicated' -Mutate {
        param($data)
        $data.rules[1].id = 'BR-0001'
    }

    Invoke-FailureCase -Name 'unknown-facet' -ExpectedMessage 'unknown facet' -Mutate {
        param($data)
        $data.rules[0].facets = @('domain.eligibility', 'domain.missing')
    }

    Invoke-FailureCase -Name 'unknown-rule-reference' -ExpectedMessage 'unknown rule' -Mutate {
        param($data)
        $data.diagrams[0].rule_refs = @('BR-9999')
    }

    Invoke-FailureCase -Name 'unknown-documentation-reference' -ExpectedMessage 'unknown documentation source' -Mutate {
        param($data)
        $data.rules[0].documentation_refs = @('DOC-9')
    }

    Invoke-FailureCase -Name 'unresolved-placeholder' -ExpectedMessage 'unresolved placeholder' -Mutate {
        param($data)
        $data.rules[0].statement = 'Submissions are rejected when {{THRESHOLD}} is not met.'
    }

    Invoke-FailureCase -Name 'source-snippet' -ExpectedMessage 'fenced code block' -Mutate {
        param($data)
        $data.rules[0].rationale = 'Copied source: ```if (age < 19) reject();```'
    }

    Invoke-FailureCase -Name 'missing-documentation-gap' -ExpectedMessage 'documentation_gap.present must be true' -Mutate {
        param($data)
        $data.documentation_gap = [ordered]@{ present = $false }
    }

    Invoke-FailureCase -Name 'mermaid-placeholder' -ExpectedMessage 'unresolved placeholder' -Mutate {
        param($data)
        $data.diagrams[0].mermaid = "flowchart TD`n  A[{{NODE_LABEL}}] --> B[Done]"
    }

    Invoke-FailureCase -Name 'mermaid-control-character' -ExpectedMessage 'control characters' -Mutate {
        param($data)
        $data.diagrams[0].mermaid = "flowchart TD`n  A[Start$([char]7)] --> B[Done]"
    }

    Invoke-FailureCase -Name 'aligned-without-available-source' -ExpectedMessage "status 'available'" -Mutate {
        param($data)
        $data.rules[0].documentation_refs = @('DOC-2')
    }

    Invoke-FailureCase -Name 'conflicting-without-available-source' -ExpectedMessage 'unverifiable' -Mutate {
        param($data)
        $data.rules[0].documentation_refs = @('DOC-2')
        $data.rules[0].reconciliation.classification = 'conflicting'
    }

    Invoke-FailureCase -Name 'facet-element-id-collision' -ExpectedMessage 'collides' -Mutate {
        param($data)
        $data.facet_groups[0].facets += , [ordered]@{ id = 'domain.fees-annual'; label = 'Annual fees' }
        $data.facet_groups += , [ordered]@{
            id     = 'domain-fees'
            label  = 'Fee domain'
            facets = @([ordered]@{ id = 'domain-fees.annual'; label = 'Annual' })
        }
    }

    # -----------------------------------------------------------------
    # 11. Malicious rendered SVG is rejected in every active context
    # -----------------------------------------------------------------
    Invoke-FailureCase -Name 'malicious-svg' -StubMode 'malicious' `
        -ExpectedMessage 'contains a script element' -Mutate { param($data) }

    Invoke-FailureCase -Name 'malicious-svg-data-url' -StubMode 'malicious-data-url' `
        -ExpectedMessage 'data: URL' -Mutate { param($data) }

    Invoke-FailureCase -Name 'malicious-svg-javascript-url' -StubMode 'malicious-javascript-url' `
        -ExpectedMessage 'javascript: URL' -Mutate { param($data) }

    Invoke-FailureCase -Name 'malicious-svg-event-attribute' -StubMode 'malicious-event-attribute' `
        -ExpectedMessage 'event handler attribute' -Mutate { param($data) }

    # -----------------------------------------------------------------
    # 12. Failing renderer process is reported, not silently ignored
    # -----------------------------------------------------------------
    Invoke-FailureCase -Name 'failing-cli' -StubMode 'failing' `
        -ExpectedMessage 'Mermaid rendering failed' -Mutate { param($data) }

    # -----------------------------------------------------------------
    # 13. Unavailable Mermaid CLI: actionable error, no partial output
    # -----------------------------------------------------------------
    $directory = New-CaseDirectory 'missing-cli'
    Save-DataFile -Directory $directory -Data (New-BaseData) | Out-Null
    $missingCliPath = Join-Path $directory 'not-installed-mmdc'
    $result = Invoke-Renderer -Directory $directory -OverrideCliPath $missingCliPath
    Assert-Condition ($result.ExitCode -ne 0) 'A missing Mermaid CLI should fail the render.'
    Assert-Contains -Text $result.Output -Expected 'does not exist' `
        -Message 'The missing Mermaid CLI error is not actionable'
    Assert-NoOutputFiles -Result $result -Name 'missing-cli'
    Write-Host 'Passed: missing Mermaid CLI fails with an actionable error and no partial output'
    $passed++

    # -----------------------------------------------------------------
    # 13b. PATH discovery finds the executable next to npm's mmdc.ps1 shim
    # -----------------------------------------------------------------
    $directory = New-CaseDirectory 'path-discovery'
    Save-DataFile -Directory $directory -Data (New-BaseData) | Out-Null
    New-PathDiscoveryStub -Directory $directory | Out-Null
    $previousPathValue = $env:PATH
    try {
        $env:PATH = $directory + [System.IO.Path]::PathSeparator + $previousPathValue
        $result = Invoke-Renderer -Directory $directory -DiscoverCliOnPath
    }
    finally {
        $env:PATH = $previousPathValue
    }
    Assert-Condition ($result.ExitCode -eq 0) `
        "PATH discovery should find the mmdc executable beside the mmdc.ps1 shim. Output: $($result.Output)"
    Assert-Condition (Test-Path -LiteralPath $result.HtmlPath) `
        'PATH discovery produced no HTML output.'
    Assert-Contains -Text ([System.IO.File]::ReadAllText($result.HtmlPath)) -Expected '<svg' `
        -Message 'PATH discovery rendered no diagram'
    Assert-Condition ($env:PATH -eq $previousPathValue) 'The test harness did not restore PATH.'
    Write-Host 'Passed: PATH discovery selects the mmdc executable, not the PowerShell shim'
    $passed++

    # -----------------------------------------------------------------
    # 13c. Mermaid checks reject directives without rejecting label text
    # -----------------------------------------------------------------
    foreach ($allowed in @(
            "flowchart TD`n  A[Call centre] --> B[Data: pending]",
            "flowchart TD`n  A[Script review] --> B[Callback owner]",
            "flowchart LR`n  A[Referral] --> B[Call centre; escalate]",
            "sequenceDiagram`n  Agent->>Queue: Call centre handoff",
            "stateDiagram-v2`n  [*] --> Draft`n  Draft --> Submitted")) {
        $mermaidErrors = New-Object 'System.Collections.Generic.List[string]'
        Test-CrowMermaidSource -Source $allowed -Path 'diagram' -Errors $mermaidErrors
        Assert-Condition ($mermaidErrors.Count -eq 0) `
            "Ordinary Mermaid label text was rejected: $($mermaidErrors -join '; ')"
    }
    foreach ($forbidden in @(
            "%%{init: {'theme':'dark'}}%%`nflowchart TD`n  A --> B",
            "flowchart TD`n  A --> B`nclick A callback",
            "flowchart TD`n  A --> B; click A href `"https://example.org`"",
            "flowchart TD`n  A --> B`nclick A href `"javascript:alert(1)`"",
            "flowchart TD`n  A[<b>bold</b>] --> B",
            "flowchart TD`n  A[x] --> B`nclick A href `"data:text/html,<script>alert(1)</script>`"",
            "flowchart TD`n  A --> B`n@import url(https://example.org/x.css)")) {
        $mermaidErrors = New-Object 'System.Collections.Generic.List[string]'
        Test-CrowMermaidSource -Source $forbidden -Path 'diagram' -Errors $mermaidErrors
        Assert-Condition ($mermaidErrors.Count -gt 0) `
            "A forbidden Mermaid construct was accepted: $forbidden"
    }
    Write-Host 'Passed: Mermaid checks allow label text and reject directives, bindings, and URLs'
    $passed++

    # -----------------------------------------------------------------
    # 13c2. Mermaid UML annotations are syntax, not raw HTML
    # -----------------------------------------------------------------
    foreach ($annotated in @(
            "classDiagram`n  class Shape`n  <<interface>> Shape`n  Shape : +area()",
            "classDiagram`n  class PaymentMethod {`n    <<interface>>`n    +pay()`n  }",
            "classDiagram`n  class Colour`n  <<enumeration>> Colour",
            "classDiagram`n  class Base`n  <<abstract>> Base",
            "classDiagram`n  class Intake`n  <<Fee service>> Intake",
            "stateDiagram-v2`n  state fork_state <<fork>>`n  [*] --> fork_state",
            "stateDiagram-v2`n  state join_state <<join>>`n  join_state --> [*]",
            "stateDiagram-v2`n  state choice_state <<choice>>`n  [*] --> choice_state")) {
        $mermaidErrors = New-Object 'System.Collections.Generic.List[string]'
        Test-CrowMermaidSource -Source $annotated -Path 'diagram' -Errors $mermaidErrors
        Assert-Condition ($mermaidErrors.Count -eq 0) `
            "A valid Mermaid UML annotation was rejected: $($annotated -replace "`n", ' / ') ($($mermaidErrors -join '; '))"
    }
    # The annotation allowance must not become a raw-HTML hole. Anything the
    # narrow grammar cannot express is still read as markup, and a stereotype
    # that names a raw-text element is still rejected.
    foreach ($stillForbidden in @(
            "classDiagram`n  class Shape`n  <<script>> Shape",
            "classDiagram`n  class Shape`n  <<a href=`"https://example.org`">> Shape",
            "classDiagram`n  class Shape`n  <<interface>> <b>Shape</b>",
            "classDiagram`n  class Shape`n  <<img src=x>>",
            "classDiagram`n  class Shape`n  << <script>alert(1)</script> >>",
            "stateDiagram-v2`n  state s <<fork>>`n  s --> <i>t</i>",
            "classDiagram`n  class Shape`n  <<interface/>> Shape")) {
        $mermaidErrors = New-Object 'System.Collections.Generic.List[string]'
        Test-CrowMermaidSource -Source $stillForbidden -Path 'diagram' -Errors $mermaidErrors
        Assert-Condition ($mermaidErrors.Count -gt 0) `
            "Raw HTML was accepted beside a UML annotation: $($stillForbidden -replace "`n", ' / ')"
    }
    # A near-miss annotation must say what the accepted grammar is, not leave the
    # author guessing why '<<...>>' was read as markup.
    $mermaidErrors = New-Object 'System.Collections.Generic.List[string]'
    Test-CrowMermaidSource -Path 'diagram' -Errors $mermaidErrors `
        -Source "classDiagram`n  class Shape`n  <<interface: fee>> Shape"
    Assert-Contains -Text ($mermaidErrors -join '; ') -Expected 'Mermaid UML annotations such as' `
        -Message 'The raw-HTML rejection does not explain the accepted annotation grammar'
    Write-Host 'Passed: Mermaid UML annotations are accepted while raw HTML is still rejected'
    $passed++

    # -----------------------------------------------------------------
    # 13d. Label text that looks like a directive renders end to end
    # -----------------------------------------------------------------
    $directory = New-CaseDirectory 'mermaid-labels'
    $data = New-BaseData
    $allowedLabels = @(
        'Call centre', 'Data: pending', 'Script review', 'Metadata: retained',
        'Renew online = allowed')
    $data.diagrams[0].mermaid = "flowchart TD`n  A[Call centre] --> B[Data: pending]`n" +
    "  B --> C[Script review]`n  C --> D[Metadata: retained]`n" +
    '  D --> E[Renew online = allowed]'
    Save-DataFile -Directory $directory -Data $data | Out-Null
    $result = Invoke-Renderer -Directory $directory
    Assert-Condition ($result.ExitCode -eq 0) `
        "A diagram with ordinary label text failed to render. Output: $($result.Output)"
    $markdown = [System.IO.File]::ReadAllText($result.MarkdownPath)
    $html = [System.IO.File]::ReadAllText($result.HtmlPath)
    foreach ($label in $allowedLabels) {
        Assert-Contains -Text $markdown -Expected $label `
            -Message 'The Markdown report lost the diagram source'
        Assert-Contains -Text $html -Expected "<tspan class=`"text-inner-tspan`">$label</tspan>" `
            -Message 'The rendered SVG lost a diagram label'
    }
    Write-Host 'Passed: diagrams with directive-like label text render end to end'
    $passed++

    # -----------------------------------------------------------------
    # 13d2. classDiagram and stateDiagram annotations render end to end
    # -----------------------------------------------------------------
    $directory = New-CaseDirectory 'mermaid-annotations'
    $data = New-BaseData
    $data.diagrams[0].mermaid = "classDiagram`n  class FeeCalculator`n" +
    "  <<interface>> FeeCalculator`n  class BaseFee {`n    <<abstract>>`n    +amount()`n  }`n" +
    "  class PermitClass`n  <<enumeration>> PermitClass`n  FeeCalculator <|-- BaseFee"
    $data.diagrams[1].mermaid = "stateDiagram-v2`n  state review_fork <<fork>>`n" +
    "  state review_join <<join>>`n  state route_choice <<choice>>`n" +
    "  [*] --> review_fork`n  review_fork --> route_choice`n  route_choice --> review_join`n" +
    '  review_join --> [*]'
    Save-DataFile -Directory $directory -Data $data | Out-Null
    $result = Invoke-Renderer -Directory $directory
    Assert-Condition ($result.ExitCode -eq 0) `
        "Mermaid UML annotations failed to render. Output: $($result.Output)"
    $markdown = [System.IO.File]::ReadAllText($result.MarkdownPath)
    $html = [System.IO.File]::ReadAllText($result.HtmlPath)
    foreach ($annotation in @('<<interface>>', '<<abstract>>', '<<enumeration>>',
            '<<fork>>', '<<join>>', '<<choice>>')) {
        Assert-Contains -Text $markdown -Expected $annotation `
            -Message 'The Markdown report lost a UML annotation from the diagram source'
    }
    Assert-Condition ((@([regex]::Matches($html, '<svg')).Count) -eq 2) `
        'Both annotated diagrams should be inlined as SVG.'
    Write-Host 'Passed: classDiagram and stateDiagram annotations render end to end'
    $passed++

    # -----------------------------------------------------------------
    # 13e. Rendered-SVG checks are scoped to markup, not to label text
    # -----------------------------------------------------------------
    $inertSvg = '<svg id="graph" xmlns="http://www.w3.org/2000/svg" ' +
    'xmlns:xlink="http://www.w3.org/1999/xlink" class="flowchart" ' +
    'style="max-width: 253px; background-color: transparent;" ' +
    'role="graphics-document document" aria-roledescription="flowchart-v2">' +
    '<style>#graph{font-family:BC Sans,Verdana;}@keyframes dash{to{stroke-dashoffset:0;}}</style>' +
    '<defs><marker id="arrowhead"><path d="M0,0 L6,3 L0,6 z"/></marker></defs>' +
    '<!-- generated --><line x1="0" y1="0" x2="9" y2="9" marker-end="url(#arrowhead)"/>' +
    '<g class="node" fill="url(#arrowhead)"><use href="#arrowhead"/>' +
    '<text y="-10.1" style=""><tspan class="text-outer-tspan" x="0" dy="1.1em">' +
    '<tspan class="text-inner-tspan">Data:</tspan>' +
    '<tspan class="text-inner-tspan"> pending</tspan></tspan></text>' +
    '<text><tspan>Metadata: retained</tspan></text>' +
    '<text><tspan>Renew online = allowed</tspan></text></g>' +
    '<title>Call centre</title>' +
    '<desc>Script review: javascript: data:text/html, url(https://example.org) @import onclick =</desc>' +
    '</svg>'
    $svgErrors = New-Object 'System.Collections.Generic.List[string]'
    Test-CrowRenderedSvg -Svg $inertSvg -Path 'diagram' -Errors $svgErrors
    Assert-Condition ($svgErrors.Count -eq 0) `
        "Inert SVG with ordinary label text was rejected: $($svgErrors -join '; ')"

    foreach ($activeSvg in @(
            '<svg><script>alert(1)</script></svg>',
            '<svg><SCRIPT>alert(1)</SCRIPT></svg>',
            '<svg><foreignObject><body/></foreignObject></svg>',
            '<svg><image href="#node"/></svg>',
            '<svg><animateTransform attributeName="transform"/></svg>',
            '<svg><set attributeName="href" to="javascript:alert(1)"/></svg>',
            '<svg><rect onload="alert(1)"/></svg>',
            '<svg><rect ONCLICK = ''alert(1)''/></svg>',
            '<svg><rect xlink:onload="alert(1)"/></svg>',
            '<svg><a href="javascript:alert(1)">x</a></svg>',
            '<svg><a href="&#106;avascript:alert(1)">x</a></svg>',
            '<svg><a xlink:href="data:text/html;base64,PHN2Zz48L3N2Zz4=">x</a></svg>',
            '<svg><use href="https://example.org/x.svg#node"/></svg>',
            '<svg><rect style="fill:url(https://example.org/x.svg#a)"/></svg>',
            '<svg><rect style="background:url(data:text/html,x)"/></svg>',
            '<svg><rect fill="url(https://example.org/x)"/></svg>',
            '<svg><style>@import url(https://example.org/x.css);</style></svg>',
            '<svg><style>.n{background:url(data:text/html,x);}</style></svg>',
            '<!DOCTYPE svg><svg><rect/></svg>',
            '<svg><!ENTITY payload "x"><rect/></svg>',
            '<svg><![CDATA[<script>alert(1)</script>]]></svg>',
            '<svg><?xml-stylesheet href="https://example.org/x.css"?><rect/></svg>',
            '<svg><rect class="unterminated</svg>')) {
        $svgErrors = New-Object 'System.Collections.Generic.List[string]'
        Test-CrowRenderedSvg -Svg $activeSvg -Path 'diagram' -Errors $svgErrors
        Assert-Condition ($svgErrors.Count -gt 0) `
            "An active SVG construct was accepted: $activeSvg"
    }
    Write-Host 'Passed: rendered-SVG checks reject active markup and allow inert label text'
    $passed++

    # -----------------------------------------------------------------
    # 13f. Template expansion is single-pass
    # -----------------------------------------------------------------
    $expanded = Expand-CrowTemplate -Template 'A={{A}} B={{B}} C={{C}}' -Values ([ordered]@{
            A = '{{B}}'
            B = 'second'
        })
    Assert-Condition ($expanded -eq 'A={{B}} B=second C={{C}}') `
        "Template expansion is not single-pass or lost an unknown placeholder: '$expanded'"
    $expanded = Expand-CrowTemplate -Template '<script>/*{{INLINE_JS}}*/</script>' -Values ([ordered]@{
            INLINE_JS = 'var total = 1;'
        })
    Assert-Condition ($expanded -eq '<script>var total = 1;</script>') `
        "Comment-wrapped injection points are not expanded: '$expanded'"
    $markdownErrors = New-Object 'System.Collections.Generic.List[string]'
    Test-CrowRenderedMarkdown -Markdown (Expand-CrowTemplate -Template '{{MISSING}}' -Values ([ordered]@{})) `
        -Errors $markdownErrors
    Assert-Condition ($markdownErrors.Count -gt 0) `
        'An unresolved placeholder should be reported by the rendered-Markdown check.'
    Write-Host 'Passed: template expansion is single-pass and reports unresolved placeholders'
    $passed++

    # -----------------------------------------------------------------
    # 13g. Rendered-output checks reject unsafe link schemes
    # -----------------------------------------------------------------
    foreach ($unsafeHtml in @('<a href="javascript:alert(1)">x</a>', '<a href="data:text/html,x">x</a>')) {
        $linkErrors = New-Object 'System.Collections.Generic.List[string]'
        Test-CrowSelfContainedHtml -Html $unsafeHtml -Errors $linkErrors
        Assert-Condition ($linkErrors.Count -gt 0) "An unsafe HTML link was accepted: $unsafeHtml"
    }
    $linkErrors = New-Object 'System.Collections.Generic.List[string]'
    Test-CrowRenderedMarkdown -Markdown '[x](javascript:alert(1))' -Errors $linkErrors
    Assert-Condition ($linkErrors.Count -gt 0) 'An unsafe Markdown link was accepted.'
    Write-Host 'Passed: rendered-output checks reject unsafe link schemes'
    $passed++

    # -----------------------------------------------------------------
    # 13h. Identifier ledger: previous data constrains the current data
    # -----------------------------------------------------------------
    $ledgerRoot = New-CaseDirectory 'ledger'
    $previousData = New-BaseData
    $previousPath = Join-Path $ledgerRoot 'previous-business-rules-data.json'
    [System.IO.File]::WriteAllText($previousPath, ($previousData | ConvertTo-Json -Depth 12), $utf8)

    function Save-LedgerCase {
        param(
            [Parameter(Mandatory)][string]$Name,
            [Parameter(Mandatory)][scriptblock]$Mutate
        )

        $data = New-BaseData
        & $Mutate $data
        $path = Join-Path $ledgerRoot "$Name.json"
        [System.IO.File]::WriteAllText($path, ($data | ConvertTo-Json -Depth 12), $utf8)
        return $path
    }

    # Unchanged data passes, and the run reports that a ledger comparison ran.
    $result = Invoke-Validator -DataPath (Save-LedgerCase -Name 'unchanged' -Mutate { param($data) }) `
        -PreviousDataPath $previousPath
    Assert-Condition ($result.ExitCode -eq 0) "An unchanged ledger comparison failed. Output: $($result.Output)"
    Assert-Contains -Text $result.Output -Expected 'accepted ledger risk(s)' `
        -Message 'The validator did not report the ledger comparison'

    # Expected evolution: a new rule is added and an active rule is retired.
    $evolvedPath = Save-LedgerCase -Name 'evolved' -Mutate {
        param($data)
        $data.rules[1].status = 'retired'
        $data.rules[1].retirement = [ordered]@{
            retired_on = '2026-02-01'
            reason     = 'The fee calculator was removed.'
        }
        $data.rules += , [ordered]@{
            id                 = 'BR-0004'
            title              = 'Withdrawn applications cannot be reopened'
            status             = 'active'
            category           = 'workflow'
            statement          = 'A withdrawn application cannot return to the submitted state.'
            facets             = @('domain.eligibility')
            citations          = @([ordered]@{
                    path   = 'src/Intake/ApplicationState.cs'
                    symbol = 'ApplicationState.Reopen'
                    commit = '0f3c1b2'
                })
            documentation_refs = @()
            reconciliation     = [ordered]@{
                classification = 'implemented-only'
                note           = 'No available document describes reopening.'
            }
        }
    }
    $result = Invoke-Validator -DataPath $evolvedPath -PreviousDataPath $previousPath
    Assert-Condition ($result.ExitCode -eq 0) "Expected ledger evolution failed. Output: $($result.Output)"

    # A previously recorded identifier may not disappear.
    $deletedPath = Save-LedgerCase -Name 'deleted-rule' -Mutate {
        param($data)
        $data.rules = @($data.rules[0], $data.rules[1])
        $data.diagrams = @($data.diagrams[0])
    }
    $result = Invoke-Validator -DataPath $deletedPath -PreviousDataPath $previousPath
    Assert-Condition ($result.ExitCode -ne 0) 'Deleting a previously recorded rule should fail.'
    Assert-Contains -Text $result.Output -Expected 'Identifiers are permanent' `
        -Message 'The deleted-identifier failure is not actionable'

    # A retired identifier may not silently reactivate.
    $reactivatedPath = Save-LedgerCase -Name 'reactivated-rule' -Mutate {
        param($data)
        $data.rules[2].status = 'active'
        $data.rules[2].Remove('retirement')
    }
    $result = Invoke-Validator -DataPath $reactivatedPath -PreviousDataPath $previousPath
    Assert-Condition ($result.ExitCode -ne 0) 'Reactivating a retired identifier should fail by default.'
    Assert-Contains -Text $result.Output -Expected '-AllowRetiredRuleReactivation' `
        -Message 'The reactivation failure does not name the override'

    # The override is explicit and reports the accepted risk.
    $result = Invoke-Validator -DataPath $reactivatedPath -PreviousDataPath $previousPath `
        -AllowRetiredRuleReactivation
    Assert-Condition ($result.ExitCode -eq 0) `
        "The explicit reactivation override should pass. Output: $($result.Output)"
    Assert-Contains -Text $result.Output -Expected 'Accepted risk' `
        -Message 'The reactivation override did not report its risk'

    # The override is meaningless, and rejected, without a ledger to compare to.
    $result = Invoke-Validator -DataPath $reactivatedPath -AllowRetiredRuleReactivation
    Assert-Condition ($result.ExitCode -ne 0) `
        'The reactivation override without -PreviousDataFile should fail.'
    Assert-Contains -Text $result.Output -Expected 'Supply -PreviousDataFile' `
        -Message 'The misused override failure is not actionable'

    # A retired number may not be reused for a different rule.
    $reusedPath = Save-LedgerCase -Name 'reused-number' -Mutate {
        param($data)
        $data.rules[2].title = 'Withdrawn applications cannot be reopened'
    }
    $result = Invoke-Validator -DataPath $reusedPath -PreviousDataPath $previousPath
    Assert-Condition ($result.ExitCode -ne 0) 'Reusing a retired number should fail.'
    Assert-Contains -Text $result.Output -Expected 'never reused' `
        -Message 'The reused-number failure is not actionable'

    # A missing ledger file is reported, not ignored.
    $result = Invoke-Validator -DataPath $evolvedPath `
        -PreviousDataPath (Join-Path $ledgerRoot 'not-present.json')
    Assert-Condition ($result.ExitCode -ne 0) 'A missing previous data file should fail.'
    Assert-Contains -Text $result.Output -Expected 'not found' `
        -Message 'The missing ledger failure is not actionable'
    Write-Host 'Passed: identifier ledger comparison fails closed and supports an explicit override'
    $passed++

    # -----------------------------------------------------------------
    # 13i. Markup tokenizer: comment terminators, unquoted values, the
    #      character the attribute scan starts on, and raw-text end tags
    # -----------------------------------------------------------------
    foreach ($smuggled in @(
            '<svg><g><!-- x --!><script>alert(1)</script><!-- y --></g></svg>',
            '<svg><g><!-- x -- y --><script>alert(1)</script></g></svg>',
            '<svg><g><!--><script>alert(1)</script>--></g></svg>',
            '<svg><g><!---><script>alert(1)</script>--></g></svg>',
            '<svg><g><!-- x --!><g onload="alert(1)"/><!-- y --></g></svg>',
            '<svg><g><!-- unterminated <script>alert(1)</script></g></svg>',
            "<svg><text data-x=a'b><script>alert(1)</script>'</text></svg>",
            '<svg><text data-x=a"b><script>alert(1)</script>"</text></svg>',
            "<svg><text data-x=a'b><g onload='alert(1)'/>'</text></svg>",
            # An '=' inside an unquoted value must not re-arm the "expecting a
            # value" state, and the quote that follows it must not open a quoted
            # value that swallows the elements after the tag.
            '<svg><text data-x=a="><script>alert(1)</script>"></text></svg>',
            "<svg><text data-x=a='><script>alert(1)</script>'></text></svg>",
            '<svg><g data-x=a="><g onload="alert(1)"/>"></g></svg>',
            '<svg><g data-x = a = "><script>alert(1)</script>"></g></svg>',
            '<svg><g data-x=a=b="><script>alert(1)</script>"></g></svg>',
            # The attribute scan starts after the tag name, so the name's own
            # letters cannot arm the "an '=' may follow a name" state, and a
            # solidus before an attribute name cannot arm it either. Each of
            # these tags therefore ends at the first '>', exactly as HTML ends
            # it, and the script that follows is a real element.
            '<svg ="><script>alert(1)</script>"></svg>',
            '<svg="><script>alert(1)</script>"></svg>',
            '<svg /="><script>alert(1)</script>"></svg>',
            '<svg><g ="><script>alert(1)</script>"></g></svg>',
            '<svg><g="><script>alert(1)</script>"></g></svg>',
            '<svg><g /="><script>alert(1)</script>"></g></svg>',
            '<svg><g ="><g onload="alert(1)"/>"></g></svg>',
            '<svg><g /="><image href="#node"/>"></g></svg>',
            # A solidus does not self-close a raw-text element, so the content
            # after it is style or script content and is checked as such.
            '<svg><style/>@import url(http://evil.example/x.css);</style></svg>',
            '<svg><style />@import url(http://evil.example/x.css);</style></svg>',
            '<svg><style/>.n{background:url(data:text/html,x);}</style></svg>',
            '<svg><script/>alert(1)</script></svg>',
            '<svg><script />alert(1)</script></svg>',
            # A raw-text end-tag name ends at whitespace, at '/', or at '>', so
            # each of these end tags closes the element for a browser and the
            # markup after it is live rather than inert raw text.
            '<svg><style>.a{fill:#fff}</style/><script>alert(1)</script></style></svg>',
            '<svg><style>.a{fill:#fff}</style foo><script>alert(1)</script></style></svg>',
            '<svg><style/>.a{fill:#fff}</style/><image href="http://evil.example/x.png"/></style></svg>',
            '<svg><style>.a{fill:#fff}</style bar="baz"><g onload="alert(1)"/></style></svg>',
            '<svg><style>.a{fill:#fff}</svg:style/><script>alert(1)</script></style></svg>',
            '<svg><style>.a{fill:#fff}</STYLE foo><script>alert(1)</script></style></svg>',
            '<svg><script>var a=1;</script/><script>alert(1)</script></script></svg>',
            '<svg><script>var a=1;</script foo><script>alert(1)</script></script></svg>',
            '<svg><script/>var a=1;</script/><image href="http://evil.example/x.png"/></script></svg>',
            '<svg><script>var a=1;</script bar="baz"><g onload="alert(1)"/></script></svg>',
            # Whitespace directly after '</' is a bogus comment for a browser,
            # so it neither closes raw text nor hides markup inside an end tag.
            '<svg><style>.a{fill:#fff}</ style><script>alert(1)</script></style></svg>',
            '<svg><g></ x foo="><script>alert(1)</script>"></g></svg>',
            # Defense in depth: valid CSS never needs a '<' in style content.
            '<svg><style>.a{fill:#fff}</styles><rect/></style></svg>',
            # ... and a raw-text element with no matching end tag is malformed.
            '<svg><style/>@import url(http://evil.example/x.css);</svg>')) {
        $svgErrors = New-Object 'System.Collections.Generic.List[string]'
        Test-CrowRenderedSvg -Svg $smuggled -Path 'diagram' -Errors $svgErrors
        Assert-Condition ($svgErrors.Count -gt 0) `
            "Markup smuggled past the tokenizer was accepted: $smuggled"
    }
    foreach ($inert in @(
            '<svg><!-- generated --><rect/></svg>',
            '<svg><!-- generated --!><rect/></svg>',
            '<svg><!----><rect/></svg>',
            "<svg><text data-x=a'b>Fee applies</text></svg>",
            '<svg><text title="a>b">Fee applies</text></svg>',
            '<svg><text data-x=a=b>Fee applies</text></svg>',
            '<svg><text data-x=a class="node">Fee applies</text></svg>',
            # Ordinary self-closing and spaced-'=' forms keep working.
            '<svg><br /><rect/></svg>',
            '<svg><use href="#a"/><rect /></svg>',
            '<svg><a href = "#node">Fee applies</a></svg>',
            '<svg><style>.node > .label { fill: #333; }</style><rect/></svg>',
            # Ordinary end tags, including the whitespace, namespace, and case
            # forms browsers accept, still close raw text without rejection.
            '<svg><style>#g .n{fill:#fff}</style ><rect/></svg>',
            '<svg><style>#g .n{fill:#fff}</svg:style><rect/></svg>',
            '<svg><style>#g .n{fill:#fff}</STYLE><rect/></svg>',
            '<svg><text>1 &lt; 2 and a &lt;/style&gt; label</text></svg>')) {
        $svgErrors = New-Object 'System.Collections.Generic.List[string]'
        Test-CrowRenderedSvg -Svg $inert -Path 'diagram' -Errors $svgErrors
        Assert-Condition ($svgErrors.Count -eq 0) `
            "Inert markup was rejected: $inert ($($svgErrors -join '; '))"
    }

    # The tokenizer itself must classify the smuggled script as a real element
    # rather than hide it inside an attribute value, and must leave the ordinary
    # self-closing and spaced-'=' forms unchanged.
    $tokenize = {
        param([string]$Markup)

        return & $businessRulesModule { param($m) Get-CrowMarkupToken -Markup $m } $Markup
    }
    $readAttribute = {
        param([string]$Tag)

        return @(& $businessRulesModule { param($t) Get-CrowMarkupAttribute -Tag $t } $Tag)
    }
    foreach ($hidden in @(
            '<svg ="><script>alert(1)</script>"></svg>',
            '<svg="><script>alert(1)</script>"></svg>',
            '<svg /="><script>alert(1)</script>"></svg>')) {
        $hiddenTokens = & $tokenize $hidden
        $scriptTokens = @($hiddenTokens | Where-Object {
                $_.Kind -eq 'element' -and -not $_.IsClosing -and
                (($_.Name -split ':')[-1]).ToLowerInvariant() -eq 'script'
            })
        Assert-Condition ($scriptTokens.Count -eq 1) `
            "The tokenizer did not report the hidden script as an element: $hidden"
        Assert-Condition (@($hiddenTokens | Where-Object { $_.Kind -eq 'malformed' }).Count -eq 0) `
            "The tokenizer should end the tag at the first '>', not fail to parse it: $hidden"
    }

    $selfClosingTokens = @(& $tokenize '<br />')
    Assert-Condition ($selfClosingTokens.Count -eq 1 -and $selfClosingTokens[0].Name -eq 'br' -and
        $selfClosingTokens[0].IsSelfClosing) '<br /> is no longer tokenized as one self-closing element.'
    $selfClosingTokens = @(& $tokenize '<img src="x"/>')
    Assert-Condition ($selfClosingTokens.Count -eq 1 -and $selfClosingTokens[0].Name -eq 'img' -and
        $selfClosingTokens[0].IsSelfClosing) '<img src="x"/> is no longer tokenized as one self-closing element.'
    $selfClosingAttributes = @(& $readAttribute $selfClosingTokens[0].Text)
    Assert-Condition ($selfClosingAttributes.Count -eq 1 -and $selfClosingAttributes[0].Name -eq 'src' -and
        $selfClosingAttributes[0].Value -eq 'x') 'The self-closing tag lost its attribute.'
    $spacedTokens = @(& $tokenize '<a href = "x">text</a>')
    Assert-Condition ($spacedTokens.Count -eq 3 -and $spacedTokens[0].Name -eq 'a' -and
        -not $spacedTokens[0].IsSelfClosing -and $spacedTokens[1].Kind -eq 'text' -and
        $spacedTokens[2].IsClosing) '<a href = "x"> is no longer tokenized as an open, text, close sequence.'
    $spacedAttributes = @(& $readAttribute $spacedTokens[0].Text)
    Assert-Condition ($spacedAttributes.Count -eq 1 -and $spacedAttributes[0].Name -eq 'href' -and
        $spacedAttributes[0].Value -eq 'x') 'A quoted value written with spaces around ''='' was lost.'

    # A raw-text end-tag name ends at whitespace, at '/', or at '>', so a
    # browser-valid end tag must end the raw text and the markup after it must be
    # tokenized as live elements instead of being swallowed as style or script
    # content.
    foreach ($rawTextCase in @(
            @{ Markup = '<style>.a{}</style/><script>alert(1)</script>'; Name = 'style' },
            @{ Markup = '<style>.a{}</style foo><script>alert(1)</script>'; Name = 'style' },
            @{ Markup = '<style>.a{}</style bar="baz"><script>alert(1)</script>'; Name = 'style' },
            @{ Markup = '<style>.a{}</svg:style/><script>alert(1)</script>'; Name = 'style' },
            @{ Markup = '<script>var a=1;</script/><script>alert(1)</script>'; Name = 'script' },
            @{ Markup = '<script>var a=1;</script foo><script>alert(1)</script>'; Name = 'script' },
            @{ Markup = '<script>var a=1;</script bar="baz"><script>alert(1)</script>'; Name = 'script' },
            @{ Markup = '<script>var a=1;</SCRIPT foo><script>alert(1)</script>'; Name = 'script' })) {
        $rawTokens = @(& $tokenize $rawTextCase.Markup)
        Assert-Condition (@($rawTokens | Where-Object { $_.Kind -eq 'malformed' }).Count -eq 0) `
            "A browser-valid raw-text end tag was not parsed: $($rawTextCase.Markup)"
        Assert-Condition ($rawTokens.Count -eq 6 -and $rawTokens[0].Kind -eq 'element' -and
            -not $rawTokens[0].IsClosing -and $rawTokens[1].Kind -eq 'text') `
            "The raw-text element was not opened as one element and one text run: $($rawTextCase.Markup)"
        Assert-Condition ($rawTokens[2].Kind -eq 'element' -and $rawTokens[2].IsClosing -and
            (($rawTokens[2].Name -split ':')[-1]).ToLowerInvariant() -eq $rawTextCase.Name -and
            -not $rawTokens[2].IsSelfClosing) `
            "The raw text was not closed by its browser-valid end tag: $($rawTextCase.Markup)"
        Assert-Condition ($rawTokens[3].Kind -eq 'element' -and -not $rawTokens[3].IsClosing -and
            (($rawTokens[3].Name -split ':')[-1]).ToLowerInvariant() -eq 'script') `
            "The element after the raw-text end tag was not tokenized as live markup: $($rawTextCase.Markup)"
        Assert-Condition (@($rawTokens | Where-Object {
                    $_.Kind -eq 'text' -and $_.Text -eq 'alert(1)'
                }).Count -eq 1) `
            "The markup after the raw-text end tag was swallowed: $($rawTextCase.Markup)"
        foreach ($textToken in @($rawTokens | Where-Object { $_.Kind -eq 'text' })) {
            Assert-NotContains -Text $textToken.Text -Unexpected '<' `
                -Message "Raw-text content kept live markup: $($rawTextCase.Markup)"
        }
    }

    # An end tag whose name is never terminated, or that never reaches its '>',
    # is malformed: the scanner must not read on to a later end tag.
    foreach ($unterminated in @(
            '<style>.a{}</style/', '<style>.a{}</style foo', '<style>.a{}</style',
            '<style>.a{}</style bar="', '<style>.a{}',
            '<script>var a=1;</script/', '<script>var a=1;</script foo',
            '<script>var a=1;</script bar="', '<script>var a=1;')) {
        $rawTokens = @(& $tokenize $unterminated)
        Assert-Condition (@($rawTokens | Where-Object { $_.Kind -eq 'malformed' }).Count -ge 1) `
            "An unterminated raw-text end tag was not reported as malformed: $unterminated"
    }

    # A longer name is a different element, so it leaves the raw text open, and
    # an ordinary end tag still closes it in one element token.
    $rawTokens = @(& $tokenize '<style>.a{}</styles>.b{}</style>')
    Assert-Condition ($rawTokens.Count -eq 3 -and $rawTokens[1].Kind -eq 'text' -and
        $rawTokens[1].Text -eq '.a{}</styles>.b{}' -and $rawTokens[2].IsClosing) `
        "'</styles>' must not close a 'style' element."
    foreach ($normal in @(
            '<style>.a{}</style>', '<style>.a{}</style >', '<style>.a{}</svg:style>',
            '<style>.a{}</STYLE>', '<script>var a=1;</script>', '<script>var a = 1 < 2;</script>')) {
        $rawTokens = @(& $tokenize $normal)
        Assert-Condition ($rawTokens.Count -eq 3 -and $rawTokens[0].Kind -eq 'element' -and
            $rawTokens[1].Kind -eq 'text' -and $rawTokens[2].Kind -eq 'element' -and
            $rawTokens[2].IsClosing -and -not $rawTokens[2].IsSelfClosing) `
            "An ordinary raw-text element is no longer tokenized as open, text, close: $normal"
    }

    # The same forms must not slip past the HTML backstop either.
    foreach ($case in @(
            @{ Html = (New-ProbeHtml -Body '<p data-x=a="><script>alert(1)</script>"></p>'); Expected = 'exactly the one inline script' },
            @{ Html = (New-ProbeHtml -Body '<p data-x=a=''><script>alert(1)</script>''></p>'); Expected = 'exactly the one inline script' },
            @{ Html = (New-ProbeHtml -Body '<p data-x=a="><img src="logo.png">"></p>'); Expected = 'uses a src attribute' },
            @{ Html = (New-ProbeHtml -Body '<p data-x=a="><span onclick="run()">x</span>"></p>'); Expected = 'inline event handler' },
            @{ Html = (New-ProbeHtml -Body '<style/>@import url(http://evil.example/x.css);</style>'); Expected = 'CSS import' },
            @{ Html = (New-ProbeHtml -Body '<style />.n{background:url(theme.png);}</style>'); Expected = 'external CSS reference' },
            @{ Html = (New-ProbeHtml -Body '<script/>alert(1)</script>'); Expected = 'exactly the one inline script' },
            @{ Html = (New-ProbeHtml -Body '<style>.a{}</style/><script>alert(1)</script></style>'); Expected = 'exactly the one inline script' },
            @{ Html = (New-ProbeHtml -Body '<style>.a{}</style foo><img src="logo.png"></style>'); Expected = 'uses a src attribute' },
            @{ Html = (New-ProbeHtml -Body '<style>.a{}</ style><script>alert(1)</script></style>'); Expected = "'<' character inside a style element" },
            # The report's own inline script is raw text, so a browser-valid
            # '</script/>' or '</script foo>' inside it ends that script and the
            # markup after it is a second, live element.
            @{ Html = (New-ProbeHtml -Script 'var total = 1;</script/><script>alert(1)'); Expected = 'exactly the one inline script' },
            @{ Html = (New-ProbeHtml -Script 'var total = 1;</script foo><img src="logo.png">'); Expected = 'uses a src attribute' },
            @{ Html = (New-ProbeHtml -Script 'var total = 1;</script bar="baz"><span onclick="run()">x</span>'); Expected = 'inline event handler' },
            @{ Html = (New-ProbeHtml -Body '<p></ x foo="><script>alert(1)</script>"></p>'); Expected = 'could not be parsed' },
            @{ Html = (New-ProbeHtml -Body '<p ="><script>alert(1)</script>"></p>'); Expected = 'exactly the one inline script' },
            @{ Html = (New-ProbeHtml -Body '<p="><script>alert(1)</script>"></p>'); Expected = 'exactly the one inline script' },
            @{ Html = (New-ProbeHtml -Body '<p /="><script>alert(1)</script>"></p>'); Expected = 'exactly the one inline script' },
            @{ Html = (New-ProbeHtml -Body '<p /="><img src="logo.png">"></p>'); Expected = 'uses a src attribute' },
            @{ Html = '<!DOCTYPE html><html><body><style/>@import url(http://evil.example/x.css);</body></html>'; Expected = 'could not be parsed' })) {
        $htmlErrors = New-Object 'System.Collections.Generic.List[string]'
        Test-CrowSelfContainedHtml -Html $case.Html -Errors $htmlErrors
        Assert-Condition ($htmlErrors.Count -gt 0) `
            "Markup smuggled past the HTML tokenizer was accepted: $($case.Html)"
        Assert-Contains -Text ($htmlErrors -join '; ') -Expected $case.Expected `
            -Message 'The smuggling failure is not specific'
    }
    Write-Host 'Passed: tokenizer rejects comment, unquoted-value, re-quoting, tag-name-scan, solidus, and raw-text end-tag smuggling'
    $passed++

    # -----------------------------------------------------------------
    # 13j. The same smuggling attempts fail a full render with no output
    # -----------------------------------------------------------------
    Invoke-FailureCase -Name 'malicious-svg-comment-terminator' `
        -StubMode 'malicious-comment-terminator' `
        -ExpectedMessage 'contains a script element' -Mutate { param($data) }

    Invoke-FailureCase -Name 'malicious-svg-comment-body' `
        -StubMode 'malicious-comment-body' `
        -ExpectedMessage 'could not be parsed' -Mutate { param($data) }

    Invoke-FailureCase -Name 'malicious-svg-unquoted-value' `
        -StubMode 'malicious-unquoted-value' `
        -ExpectedMessage 'contains a script element' -Mutate { param($data) }

    Invoke-FailureCase -Name 'malicious-svg-unquoted-requote' `
        -StubMode 'malicious-unquoted-requote' `
        -ExpectedMessage 'contains a script element' -Mutate { param($data) }

    Invoke-FailureCase -Name 'malicious-svg-unquoted-requote-handler' `
        -StubMode 'malicious-unquoted-requote-handler' `
        -ExpectedMessage 'event handler attribute' -Mutate { param($data) }

    Invoke-FailureCase -Name 'malicious-svg-solidus-style' `
        -StubMode 'malicious-solidus-style' `
        -ExpectedMessage 'CSS import' -Mutate { param($data) }

    Invoke-FailureCase -Name 'malicious-svg-solidus-script' `
        -StubMode 'malicious-solidus-script' `
        -ExpectedMessage 'contains a script element' -Mutate { param($data) }

    # A browser-valid raw-text end tag ends the raw text, so the markup that
    # follows it is checked as live markup and the run produces no document.
    Invoke-FailureCase -Name 'malicious-svg-end-tag-solidus-style' `
        -StubMode 'malicious-end-tag-solidus-style' `
        -ExpectedMessage 'contains a script element' -Mutate { param($data) }

    Invoke-FailureCase -Name 'malicious-svg-end-tag-attribute-style' `
        -StubMode 'malicious-end-tag-attribute-style' `
        -ExpectedMessage 'contains an image element' -Mutate { param($data) }

    Invoke-FailureCase -Name 'malicious-svg-end-tag-solidus-script' `
        -StubMode 'malicious-end-tag-solidus-script' `
        -ExpectedMessage 'event handler attribute' -Mutate { param($data) }

    Invoke-FailureCase -Name 'malicious-svg-end-tag-attribute-script' `
        -StubMode 'malicious-end-tag-attribute-script' `
        -ExpectedMessage 'contains a script element' -Mutate { param($data) }

    # -----------------------------------------------------------------
    # 13k. HTML backstop: exactly one inline script, and no false positives
    # -----------------------------------------------------------------
    $htmlErrors = New-Object 'System.Collections.Generic.List[string]'
    Test-CrowSelfContainedHtml -Html (New-ProbeHtml -Body (
            '<p>Visible report text may mention the src= attribute, url(theme.png), ' +
            'integrity = checked, and a literal [fee](applies) without being a subresource.</p>' +
            '<p>&lt;script&gt;alert(1)&lt;/script&gt; stays escaped prose.</p>')) `
        -Errors $htmlErrors
    Assert-Condition ($htmlErrors.Count -eq 0) `
        "Benign report prose was rejected by the self-contained check: $($htmlErrors -join '; ')"

    $htmlErrors = New-Object 'System.Collections.Generic.List[string]'
    Test-CrowSelfContainedHtml -Html (New-ProbeHtml -Script 'var total = 1;') `
        -Errors $htmlErrors -ExpectedInlineScript 'var total = 1;'
    Assert-Condition ($htmlErrors.Count -eq 0) `
        "The expected inline script was rejected: $($htmlErrors -join '; ')"

    # The '<' invariant applies to style content only: the bundled report script
    # legitimately compares with '<' inside its raw text.
    $htmlErrors = New-Object 'System.Collections.Generic.List[string]'
    Test-CrowSelfContainedHtml -Html (New-ProbeHtml -Script 'for (i = 0; i < items.length; i += 1) { keep(i); }') `
        -Errors $htmlErrors -ExpectedInlineScript 'for (i = 0; i < items.length; i += 1) { keep(i); }'
    Assert-Condition ($htmlErrors.Count -eq 0) `
        "An inline script that compares with '<' was rejected: $($htmlErrors -join '; ')"

    foreach ($case in @(
            @{ Html = (New-ProbeHtml -Body '<p>Rules</p><script>alert(1)</script>'); Expected = 'exactly the one inline script' },
            @{ Html = (New-ProbeHtml -Body '<div><script src="analytics.js"></script></div>'); Expected = 'exactly the one inline script' },
            @{ Html = '<!DOCTYPE html><html><body><p>No script at all.</p></body></html>'; Expected = 'exactly the one inline script' },
            @{ Html = (New-ProbeHtml -Body '<img src="logo.png" alt="">'); Expected = 'uses a src attribute' },
            @{ Html = (New-ProbeHtml -Body '<span integrity="sha384-abc">x</span>'); Expected = 'subresource integrity hash' },
            @{ Html = (New-ProbeHtml -Body '<div style="background:url(theme.png)">x</div>'); Expected = 'external CSS reference' },
            @{ Html = (New-ProbeHtml -Style '@import url(https://example.org/x.css);'); Expected = 'CSS import' },
            @{ Html = (New-ProbeHtml -Body '<a href="http://example.org">x</a>'); Expected = 'unsafe or external href' },
            @{ Html = (New-ProbeHtml -Body '<iframe></iframe>'); Expected = 'embedded object element' },
            @{ Html = (New-ProbeHtml -Body '<p onclick="run()">x</p>'); Expected = 'inline event handler' },
            @{ Html = (New-ProbeHtml -Body '<p>{{RULE_COUNT}}</p>'); Expected = 'unresolved placeholder' },
            @{ Html = (New-ProbeHtml -Body '<![CDATA[x> <script>alert(1)</script> ]]>'); Expected = 'CDATA section' },
            @{ Html = (New-ProbeHtml -Body '<?xml-stylesheet href="https://example.org/x.css"?>'); Expected = 'processing instruction' },
            @{ Html = (New-ProbeHtml -Body '<!ENTITY payload "x">'); Expected = 'unsupported' },
            @{ Html = (New-ProbeHtml -Body '<p><!--><script>alert(1)</script>--></p>'); Expected = 'exactly the one inline script' })) {
        $htmlErrors = New-Object 'System.Collections.Generic.List[string]'
        Test-CrowSelfContainedHtml -Html $case.Html -Errors $htmlErrors
        Assert-Condition ($htmlErrors.Count -gt 0) "An unsafe report document was accepted: $($case.Html)"
        Assert-Contains -Text ($htmlErrors -join '; ') -Expected $case.Expected `
            -Message 'The self-contained failure is not specific'
    }

    $htmlErrors = New-Object 'System.Collections.Generic.List[string]'
    Test-CrowSelfContainedHtml -Html (New-ProbeHtml -Body '<script defer>var x = 1;</script>' -Script '') `
        -Errors $htmlErrors
    Assert-Contains -Text ($htmlErrors -join '; ') -Expected 'carries attributes' `
        -Message 'A script element with attributes was accepted'

    $htmlErrors = New-Object 'System.Collections.Generic.List[string]'
    Test-CrowSelfContainedHtml -Html (New-ProbeHtml -Script 'var total = 2;') `
        -Errors $htmlErrors -ExpectedInlineScript 'var total = 1;'
    Assert-Contains -Text ($htmlErrors -join '; ') -Expected 'bundled report script' `
        -Message 'A replaced inline script body was accepted'
    Write-Host 'Passed: HTML backstop enforces one inline script and ignores visible prose'
    $passed++

    # -----------------------------------------------------------------
    # 13l. Markdown link checks ignore escaped prose, not real links
    # -----------------------------------------------------------------
    foreach ($safeMarkdown in @(
            'A literal \[fee\](applies) note.',
            'Prose about url(theme.png) and src= stays prose.',
            '[Anchor](#rules) and [Guide](https://example.org/guide) are allowed.')) {
        $markdownErrors = New-Object 'System.Collections.Generic.List[string]'
        Test-CrowRenderedMarkdown -Markdown $safeMarkdown -Errors $markdownErrors
        Assert-Condition ($markdownErrors.Count -eq 0) `
            "Benign Markdown was rejected: $safeMarkdown ($($markdownErrors -join '; '))"
    }
    foreach ($unsafeMarkdown in @(
            '[x](javascript:alert(1))',
            '[x](http://example.org)',
            '[x](data:text/html,x)')) {
        $markdownErrors = New-Object 'System.Collections.Generic.List[string]'
        Test-CrowRenderedMarkdown -Markdown $unsafeMarkdown -Errors $markdownErrors
        Assert-Condition ($markdownErrors.Count -gt 0) `
            "An unsafe Markdown link was accepted: $unsafeMarkdown"
    }
    Write-Host 'Passed: Markdown link checks ignore escaped prose and reject real unsafe links'
    $passed++

    # -----------------------------------------------------------------
    # 13m. Mermaid source may not close the Markdown code fence
    # -----------------------------------------------------------------
    foreach ($fenced in @(
            "flowchart TD`n  A --> B`n``````" + "`n## Injected heading",
            "flowchart TD`n  A --> B`n   ``````mermaid",
            "flowchart TD`n  A --> B`n````````````")) {
        $mermaidErrors = New-Object 'System.Collections.Generic.List[string]'
        Test-CrowMermaidSource -Source $fenced -Path 'diagram' -Errors $mermaidErrors
        Assert-Condition ($mermaidErrors.Count -gt 0) `
            "Mermaid source that closes the Markdown fence was accepted: $fenced"
    }
    Invoke-FailureCase -Name 'mermaid-markdown-fence' -ExpectedMessage 'code fences' -Mutate {
        param($data)
        $data.diagrams[0].mermaid = "flowchart TD`n  A[Start] --> B[Done]`n``````" +
        "`n## Injected`n<script>alert(1)</script>"
    }

    # -----------------------------------------------------------------
    # 13n. Benign report text renders end to end
    # -----------------------------------------------------------------
    $directory = New-CaseDirectory 'benign-text'
    $data = New-BaseData
    $data.rules[0].statement = 'Reports may mention the src= attribute, url(theme.png), ' +
    'integrity = checked, and a literal [fee](applies) fee note.'
    $data.rules[0].rationale = 'The intake guide writes @import and href= in prose.'
    $data.open_questions = @('Does url(theme.png) in a caption need a review?')
    $data.diagrams[0].mermaid = "flowchart TD`n  A[Fee url(x)] --> B[Data: pending]"
    Save-DataFile -Directory $directory -Data $data | Out-Null
    $result = Invoke-Renderer -Directory $directory
    Assert-Condition ($result.ExitCode -eq 0) `
        "Benign report text failed to render. Output: $($result.Output)"
    $markdown = [System.IO.File]::ReadAllText($result.MarkdownPath)
    $html = [System.IO.File]::ReadAllText($result.HtmlPath)
    foreach ($expected in @('src=', 'url(theme.png)', 'integrity = checked', 'url(x)')) {
        Assert-Contains -Text $html -Expected $expected -Message 'The HTML report lost benign text'
    }
    Assert-Contains -Text $markdown -Expected '\[fee\](applies)' `
        -Message 'The Markdown report lost the escaped literal link'
    Assert-Contains -Text $markdown -Expected 'url(theme.png)' `
        -Message 'The Markdown report lost benign text'
    Write-Host 'Passed: benign report text renders instead of tripping the security checks'
    $passed++

    # -----------------------------------------------------------------
    # 13o. Publication is pairwise: a failure leaves both targets unchanged
    # -----------------------------------------------------------------
    $directory = New-CaseDirectory 'publish-pair'
    $markdownTarget = Join-Path $directory 'business-rules.md'
    $htmlTarget = Join-Path $directory 'business-rules.html'
    Write-CrowDocumentPair -Documents ([ordered]@{
            $markdownTarget = "# first`r`n"
            $htmlTarget     = '<p>first</p>'
        })
    Assert-Condition ([System.IO.File]::ReadAllText($markdownTarget) -eq "# first`n") `
        'The pair writer did not normalize line endings.'
    Assert-Condition ([System.IO.File]::ReadAllBytes($markdownTarget)[0] -ne 239) `
        'The pair writer wrote a UTF-8 BOM.'

    $blockedDirectory = New-CaseDirectory 'publish-pair-blocked'
    $blockedMarkdown = Join-Path $blockedDirectory 'business-rules.md'
    [System.IO.File]::WriteAllText($blockedMarkdown, "# stale`n", $utf8)
    New-Item -ItemType Directory -Path (Join-Path $blockedDirectory 'business-rules.html') -Force | Out-Null
    $publishFailed = $false
    try {
        Write-CrowDocumentPair -Documents ([ordered]@{
                $blockedMarkdown                                     = "# fresh`n"
                (Join-Path $blockedDirectory 'business-rules.html') = '<p>fresh</p>'
            })
    }
    catch {
        $publishFailed = $true
    }
    Assert-Condition $publishFailed 'Publishing over a blocked target should fail.'
    Assert-Condition ([System.IO.File]::ReadAllText($blockedMarkdown) -eq "# stale`n") `
        'A failed publication replaced the first document and left a mixed pair.'
    Assert-Condition ((Get-TemporaryArtifact -Directory $blockedDirectory).Count -eq 0) `
        'A failed publication left staging or backup files behind.'

    $directory = New-CaseDirectory 'render-publish-failure'
    Save-DataFile -Directory $directory -Data (New-BaseData) | Out-Null
    $publishFailurePrevious = Join-Path $directory 'previous-business-rules-data.json'
    [System.IO.File]::WriteAllText($publishFailurePrevious, ((New-BaseData) | ConvertTo-Json -Depth 12), $utf8)
    $staleMarkdown = Join-Path $directory 'business-rules.md'
    [System.IO.File]::WriteAllText($staleMarkdown, "# stale report`n", $utf8)
    New-Item -ItemType Directory -Path (Join-Path $directory 'business-rules.html') -Force | Out-Null
    $result = Invoke-Renderer -Directory $directory -PreviousDataPath $publishFailurePrevious
    Assert-Condition ($result.ExitCode -ne 0) 'A blocked HTML target should fail the render.'
    Assert-Condition ([System.IO.File]::ReadAllText($staleMarkdown) -eq "# stale report`n") `
        "A failed render replaced the Markdown document. Output: $($result.Output)"
    Assert-Condition ((Get-TemporaryArtifact -Directory $directory).Count -eq 0) `
        'A failed render left staging or backup files behind.'

    # A failure between the two replacements restores the first document. File
    # sharing is only enforced on Windows, so the case is skipped elsewhere.
    if ($env:OS -eq 'Windows_NT') {
        $lockDirectory = New-CaseDirectory 'publish-pair-locked'
        $lockedMarkdown = Join-Path $lockDirectory 'business-rules.md'
        $lockedHtml = Join-Path $lockDirectory 'business-rules.html'
        [System.IO.File]::WriteAllText($lockedMarkdown, "# stale`n", $utf8)
        [System.IO.File]::WriteAllText($lockedHtml, '<p>stale</p>', $utf8)
        $handle = [System.IO.File]::Open($lockedHtml, 'Open', 'Read', 'None')
        $publishFailed = $false
        try {
            Write-CrowDocumentPair -Documents ([ordered]@{
                    $lockedMarkdown = "# fresh`n"
                    $lockedHtml     = '<p>fresh</p>'
                })
        }
        catch {
            $publishFailed = $true
        }
        finally {
            $handle.Dispose()
        }
        Assert-Condition $publishFailed 'Publishing over a locked target should fail.'
        Assert-Condition ([System.IO.File]::ReadAllText($lockedMarkdown) -eq "# stale`n") `
            'A mid-publication failure left a mixed pair: the Markdown document was replaced.'
        Assert-Condition ([System.IO.File]::ReadAllText($lockedHtml) -eq '<p>stale</p>') `
            'A mid-publication failure changed the HTML document.'
        Assert-Condition ((Get-TemporaryArtifact -Directory $lockDirectory).Count -eq 0) `
            'A restored publication left staging or backup files behind.'
    }
    else {
        Write-Host 'Note: the mid-publication restore case needs Windows file-sharing semantics and was skipped.'
    }
    Write-Host 'Passed: both documents are published together or not at all'
    $passed++

    # -----------------------------------------------------------------
    # 13o2. A move that fails after its target was deleted restores every
    #       attempted document, including the one whose delete had succeeded
    # -----------------------------------------------------------------
    # Move-CrowStagedDocument is the single destructive step of a publication.
    # Redefining it inside the module's own scope makes the delete-success /
    # move-failure window deterministic on every platform, with no file locks
    # and no special privileges.
    $injectDirectory = New-CaseDirectory 'publish-pair-move-failure'
    $injectMarkdown = Join-Path $injectDirectory 'business-rules.md'
    $injectHtml = Join-Path $injectDirectory 'business-rules.html'
    [System.IO.File]::WriteAllText($injectMarkdown, "# stale`n", $utf8)
    [System.IO.File]::WriteAllText($injectHtml, '<p>stale</p>', $utf8)
    try {
        & $businessRulesModule {
            $script:CrowTestMoveCount = 0
            # 'script:' inside the module's session state is the module scope, so
            # the replacement is the one Write-CrowDocumentPair resolves.
            function script:Move-CrowStagedDocument {
                param(
                    [Parameter(Mandatory)][string]$Staging,
                    [Parameter(Mandatory)][string]$Path
                )

                $script:CrowTestMoveCount++
                # The first document is genuinely replaced. The second one has
                # already had its target deleted when this throws.
                if ($script:CrowTestMoveCount -ge 2) {
                    throw "Injected move failure for '$Path'."
                }
                [System.IO.File]::Move($Staging, $Path)
            }
        }

        $publishFailed = $false
        $publishWarnings = @()
        try {
            Write-CrowDocumentPair -Documents ([ordered]@{
                    $injectMarkdown = "# fresh`n"
                    $injectHtml     = '<p>fresh</p>'
                }) -WarningVariable publishWarnings -WarningAction SilentlyContinue
        }
        catch {
            $publishFailed = $true
        }
        Assert-Condition $publishFailed 'An injected move failure should fail the publication.'
        Assert-Condition (@($publishWarnings).Count -eq 0) `
            "Every attempted document should have been restored: $(@($publishWarnings) -join '; ')"
        Assert-Condition (Test-Path -LiteralPath $injectMarkdown -PathType Leaf) `
            'The already-replaced document was not restored after an injected move failure.'
        Assert-Condition ([System.IO.File]::ReadAllText($injectMarkdown) -eq "# stale`n") `
            'The already-replaced document was not restored to its previous content.'
        Assert-Condition (Test-Path -LiteralPath $injectHtml -PathType Leaf) `
            'The document whose delete succeeded and whose move failed was lost entirely.'
        Assert-Condition ([System.IO.File]::ReadAllText($injectHtml) -eq '<p>stale</p>') `
            'The document deleted in the failed move window was not restored from its backup.'
        Assert-Condition ((Get-TemporaryArtifact -Directory $injectDirectory).Count -eq 0) `
            'A restored publication left staging or backup files behind.'
    }
    finally {
        Import-Module $modulePath -Force
        $businessRulesModule = Get-Module 'CrowBusinessRules'
    }
    Assert-Condition (& $businessRulesModule { $null -eq (Get-Variable 'CrowTestMoveCount' -Scope Script -ErrorAction SilentlyContinue) }) `
        'The test harness left its injected failure state in the module.'
    Write-Host 'Passed: a move that fails after a delete restores every attempted document'
    $passed++

    # -----------------------------------------------------------------
    # 13o3. A backup is kept, with a warning, when its document cannot be
    #       restored, so the only remaining copy is never discarded
    # -----------------------------------------------------------------
    $keepDirectory = New-CaseDirectory 'publish-pair-restore-failure'
    $keepMarkdown = Join-Path $keepDirectory 'business-rules.md'
    $keepHtml = Join-Path $keepDirectory 'business-rules.html'
    [System.IO.File]::WriteAllText($keepMarkdown, "# stale`n", $utf8)
    [System.IO.File]::WriteAllText($keepHtml, '<p>stale</p>', $utf8)
    try {
        & $businessRulesModule {
            param([Parameter(Mandatory)][string]$BlockedPath)

            $script:CrowTestMoveCount = 0
            $script:CrowTestBlockedPath = $BlockedPath
            function script:Move-CrowStagedDocument {
                param(
                    [Parameter(Mandatory)][string]$Staging,
                    [Parameter(Mandatory)][string]$Path
                )

                $script:CrowTestMoveCount++
                if ($script:CrowTestMoveCount -lt 2) {
                    [System.IO.File]::Move($Staging, $Path)
                    return
                }
                # Make the first document impossible to restore: a directory now
                # occupies its path, so the restoring copy cannot succeed.
                $blocked = $script:CrowTestBlockedPath
                [System.IO.File]::Delete($blocked)
                New-Item -ItemType Directory -Path $blocked -Force | Out-Null
                throw "Injected move failure for '$Path'."
            }
        } $keepMarkdown

        $publishFailed = $false
        $publishWarnings = @()
        try {
            Write-CrowDocumentPair -Documents ([ordered]@{
                    $keepMarkdown = "# fresh`n"
                    $keepHtml     = '<p>fresh</p>'
                }) -WarningVariable publishWarnings -WarningAction SilentlyContinue
        }
        catch {
            $publishFailed = $true
        }
        Assert-Condition $publishFailed 'An injected move failure should fail the publication.'
        Assert-Condition (@($publishWarnings).Count -eq 1) `
            "An unrestorable document should warn exactly once: $(@($publishWarnings) -join '; ')"
        Assert-Contains -Text ([string]@($publishWarnings)[0]) -Expected 'is kept at' `
            -Message 'The warning does not say where the previous document was kept'
        $keptBackups = @(Get-ChildItem -LiteralPath $keepDirectory -File |
                Where-Object { $_.Name -like '*.bak' })
        Assert-Condition ($keptBackups.Count -eq 1) `
            "The only remaining copy of the unrestorable document was discarded ($($keptBackups.Count) backup(s) kept)."
        Assert-Condition ([System.IO.File]::ReadAllText($keptBackups[0].FullName) -eq "# stale`n") `
            'The kept backup does not hold the previous document.'
        Assert-Condition ((@(Get-ChildItem -LiteralPath $keepDirectory -File |
                        Where-Object { $_.Name -like '*.tmp' })).Count -eq 0) `
            'A failed publication left staging files behind.'
        Assert-Condition ([System.IO.File]::ReadAllText($keepHtml) -eq '<p>stale</p>') `
            'The restorable document was not restored from its backup.'
    }
    finally {
        Import-Module $modulePath -Force
        $businessRulesModule = Get-Module 'CrowBusinessRules'
    }
    Write-Host 'Passed: an unrestorable document keeps its backup and reports where it is'
    $passed++

    # -----------------------------------------------------------------
    # 13p. The renderer enforces the identifier ledger itself
    # -----------------------------------------------------------------
    $directory = New-CaseDirectory 'render-ledger'
    $previousRenderPath = Join-Path $directory 'previous-business-rules-data.json'
    [System.IO.File]::WriteAllText($previousRenderPath, ((New-BaseData) | ConvertTo-Json -Depth 12), $utf8)
    Save-DataFile -Directory $directory -Data (New-BaseData) | Out-Null
    $result = Invoke-Renderer -Directory $directory -PreviousDataPath $previousRenderPath
    Assert-Condition ($result.ExitCode -eq 0) `
        "An unchanged ledger should render. Output: $($result.Output)"

    $directory = New-CaseDirectory 'render-ledger-deleted'
    [System.IO.File]::WriteAllText(
        (Join-Path $directory 'previous-business-rules-data.json'),
        ((New-BaseData) | ConvertTo-Json -Depth 12), $utf8)
    $deletedData = New-BaseData
    $deletedData.rules = @($deletedData.rules[0], $deletedData.rules[1])
    $deletedData.diagrams = @($deletedData.diagrams[0])
    Save-DataFile -Directory $directory -Data $deletedData | Out-Null
    $result = Invoke-Renderer -Directory $directory `
        -PreviousDataPath (Join-Path $directory 'previous-business-rules-data.json')
    Assert-Condition ($result.ExitCode -ne 0) 'The renderer accepted a deleted rule identifier.'
    Assert-Contains -Text $result.Output -Expected 'Identifiers are permanent' `
        -Message 'The render-time ledger failure is not actionable'
    Assert-NoOutputFiles -Result $result -Name 'render-ledger-deleted'

    $directory = New-CaseDirectory 'render-ledger-reactivated'
    $previousRenderPath = Join-Path $directory 'previous-business-rules-data.json'
    [System.IO.File]::WriteAllText($previousRenderPath, ((New-BaseData) | ConvertTo-Json -Depth 12), $utf8)
    $reactivatedData = New-BaseData
    $reactivatedData.rules[2].status = 'active'
    $reactivatedData.rules[2].Remove('retirement')
    Save-DataFile -Directory $directory -Data $reactivatedData | Out-Null
    $result = Invoke-Renderer -Directory $directory -PreviousDataPath $previousRenderPath
    Assert-Condition ($result.ExitCode -ne 0) 'The renderer reactivated a retired identifier silently.'
    Assert-Contains -Text $result.Output -Expected '-AllowRetiredRuleReactivation' `
        -Message 'The render-time reactivation failure does not name the override'
    Assert-NoOutputFiles -Result $result -Name 'render-ledger-reactivated'

    $result = Invoke-Renderer -Directory $directory -PreviousDataPath $previousRenderPath `
        -AllowRetiredRuleReactivation
    Assert-Condition ($result.ExitCode -eq 0) `
        "The explicit render-time override should render. Output: $($result.Output)"
    Assert-Contains -Text $result.Output -Expected 'Accepted risk' `
        -Message 'The render-time override did not report its risk'

    $directory = New-CaseDirectory 'render-ledger-misused-override'
    Save-DataFile -Directory $directory -Data (New-BaseData) | Out-Null
    $result = Invoke-Renderer -Directory $directory -AllowRetiredRuleReactivation
    Assert-Condition ($result.ExitCode -ne 0) `
        'The renderer accepted the override without a ledger to compare to.'
    Assert-Contains -Text $result.Output -Expected 'Supply -PreviousDataFile' `
        -Message 'The misused render-time override failure is not actionable'
    Assert-NoOutputFiles -Result $result -Name 'render-ledger-misused-override'

    $directory = New-CaseDirectory 'render-ledger-missing'
    Save-DataFile -Directory $directory -Data (New-BaseData) | Out-Null
    $result = Invoke-Renderer -Directory $directory `
        -PreviousDataPath (Join-Path $directory 'not-present.json')
    Assert-Condition ($result.ExitCode -ne 0) 'A missing ledger file should fail the render.'
    Assert-Contains -Text $result.Output -Expected 'not found' `
        -Message 'The missing render-time ledger failure is not actionable'
    Assert-NoOutputFiles -Result $result -Name 'render-ledger-missing'
    Write-Host 'Passed: render-time ledger enforcement fails closed and supports the explicit override'
    $passed++

    # -----------------------------------------------------------------
    # 13p2. A regeneration may not skip the ledger: an existing document
    #       makes -PreviousDataFile mandatory
    # -----------------------------------------------------------------
    # First-time generation is allowed without a ledger, and it creates the pair.
    $directory = New-CaseDirectory 'render-ledger-first-run'
    Save-DataFile -Directory $directory -Data (New-BaseData) | Out-Null
    $result = Invoke-Renderer -Directory $directory
    Assert-Condition ($result.ExitCode -eq 0) `
        "First-time generation should not require a ledger. Output: $($result.Output)"
    Assert-Condition (Test-Path -LiteralPath $result.MarkdownPath) 'First-time generation wrote no Markdown.'
    Assert-Condition (Test-Path -LiteralPath $result.HtmlPath) 'First-time generation wrote no HTML.'

    # The same directory is now a regeneration, and the ledger is mandatory.
    $existingMarkdown = [System.IO.File]::ReadAllText($result.MarkdownPath)
    $existingHtml = [System.IO.File]::ReadAllText($result.HtmlPath)
    $result = Invoke-Renderer -Directory $directory
    Assert-Condition ($result.ExitCode -ne 0) `
        'Regenerating over an existing report without -PreviousDataFile should fail.'
    foreach ($expected in @(
            'This is a regeneration',
            '-PreviousDataFile is required',
            'Export-PreviousBusinessRuleData.ps1',
            'No output files were written')) {
        Assert-Contains -Text $result.Output -Expected $expected `
            -Message 'The refused regeneration is not actionable'
    }
    Assert-Condition ([System.IO.File]::ReadAllText($result.MarkdownPath) -eq $existingMarkdown) `
        'A refused regeneration changed the existing Markdown document.'
    Assert-Condition ([System.IO.File]::ReadAllText($result.HtmlPath) -eq $existingHtml) `
        'A refused regeneration changed the existing HTML document.'
    Assert-Condition ((Get-TemporaryArtifact -Directory $directory).Count -eq 0) `
        'A refused regeneration left staging or backup files behind.'

    # Supplying the ledger makes the same regeneration succeed.
    $firstRunPrevious = Join-Path $directory 'previous-business-rules-data.json'
    [System.IO.File]::WriteAllText($firstRunPrevious, ((New-BaseData) | ConvertTo-Json -Depth 12), $utf8)
    $result = Invoke-Renderer -Directory $directory -PreviousDataPath $firstRunPrevious
    Assert-Condition ($result.ExitCode -eq 0) `
        "A regeneration with the ledger should succeed. Output: $($result.Output)"

    # Either document on its own is enough to make the run a regeneration.
    foreach ($orphan in @('business-rules.md', 'business-rules.html')) {
        $directory = New-CaseDirectory ('render-ledger-orphan-' + $orphan.Replace('.', '-'))
        Save-DataFile -Directory $directory -Data (New-BaseData) | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $directory $orphan), 'stale', $utf8)
        $result = Invoke-Renderer -Directory $directory
        Assert-Condition ($result.ExitCode -ne 0) `
            "An existing $orphan should make -PreviousDataFile mandatory."
        Assert-Contains -Text $result.Output -Expected 'Export-PreviousBusinessRuleData.ps1' `
            -Message 'The refused regeneration does not name the exporter'
        Assert-Condition ([System.IO.File]::ReadAllText((Join-Path $directory $orphan)) -eq 'stale') `
            "A refused regeneration changed the existing $orphan."
    }
    Write-Host 'Passed: a regeneration cannot skip the identifier ledger'
    $passed++

    # -----------------------------------------------------------------
    # 13p3. The bundled help points at the byte-safe exporter, not at shell
    #       redirection that corrupts non-ASCII rule text
    # -----------------------------------------------------------------
    foreach ($helpedScript in @($validatorPath, $rendererPath)) {
        $helpText = [System.IO.File]::ReadAllText($helpedScript)
        Assert-Contains -Text $helpText -Expected 'Export-PreviousBusinessRuleData.ps1' `
            -Message "$(Split-Path -Leaf $helpedScript) does not point at the byte-safe exporter"
        Assert-Condition (-not [regex]::IsMatch($helpText, 'git\s+show[^\r\n]*>')) `
            ("$(Split-Path -Leaf $helpedScript) still documents 'git show ... >' redirection, " +
            'which rewrites the ledger as UTF-16 in Windows PowerShell 5.1.')
    }
    Write-Host 'Passed: bundled help documents the byte-safe ledger exporter'
    $passed++

    # -----------------------------------------------------------------
    # 13q. Ledger extraction preserves the committed bytes
    # -----------------------------------------------------------------
    $directory = New-CaseDirectory 'ledger-extraction'
    $committedJson = '{"schema_version":"1.0","note":"Frais — créés à Montréal 政策"}'
    $stubGitPath = New-StubGit -Directory $directory -Payload $committedJson
    $destinationPath = Join-Path $directory 'previous-business-rules-data.json'
    $result = Invoke-Exporter -Destination $destinationPath -GitPath $stubGitPath
    Assert-Condition ($result.ExitCode -eq 0) "Ledger extraction failed. Output: $($result.Output)"
    $extractedBytes = [System.IO.File]::ReadAllBytes($destinationPath)
    $expectedBytes = [System.Text.Encoding]::UTF8.GetBytes($committedJson)
    Assert-Condition ($extractedBytes.Length -eq $expectedBytes.Length) `
        "Ledger extraction changed the committed byte length: $($extractedBytes.Length) instead of $($expectedBytes.Length)."
    for ($byteIndex = 0; $byteIndex -lt $expectedBytes.Length; $byteIndex++) {
        Assert-Condition ($extractedBytes[$byteIndex] -eq $expectedBytes[$byteIndex]) `
            "Ledger extraction changed byte $byteIndex of the committed data file."
    }
    Assert-Contains -Text ([System.IO.File]::ReadAllText($destinationPath)) -Expected 'Frais — créés à Montréal 政策' `
        -Message 'Ledger extraction lost non-ASCII content'

    $directory = New-CaseDirectory 'ledger-extraction-failure'
    $failingGitPath = New-StubGit -Directory $directory -Payload '' -ExitCode 3
    $destinationPath = Join-Path $directory 'previous-business-rules-data.json'
    $result = Invoke-Exporter -Destination $destinationPath -GitPath $failingGitPath
    Assert-Condition ($result.ExitCode -ne 0) 'A failing git extraction should fail the step.'
    Assert-Condition (-not (Test-Path -LiteralPath $destinationPath)) `
        'A failed extraction wrote a destination file.'
    Assert-Contains -Text $result.Output -Expected 'exit code 3' `
        -Message 'The extraction failure is not actionable'

    $directory = New-CaseDirectory 'ledger-extraction-not-json'
    $textGitPath = New-StubGit -Directory $directory -Payload 'not json at all'
    $destinationPath = Join-Path $directory 'previous-business-rules-data.json'
    $result = Invoke-Exporter -Destination $destinationPath -GitPath $textGitPath
    Assert-Condition ($result.ExitCode -ne 0) 'A non-JSON extraction should fail the step.'
    Assert-Condition (-not (Test-Path -LiteralPath $destinationPath)) `
        'A non-JSON extraction wrote a destination file.'
    Assert-Condition ((Get-TemporaryArtifact -Directory $directory).Count -eq 0) `
        'A failed extraction left staging files behind.'

    $directory = New-CaseDirectory 'ledger-extraction-missing-git'
    $result = Invoke-Exporter -Destination (Join-Path $directory 'previous.json') `
        -GitPath (Join-Path $directory 'not-installed-git')
    Assert-Condition ($result.ExitCode -ne 0) 'A missing git executable should fail the step.'
    Assert-Contains -Text $result.Output -Expected 'does not exist' `
        -Message 'The missing git error is not actionable'
    Write-Host 'Passed: ledger extraction preserves committed bytes and fails closed'
    $passed++

    # -----------------------------------------------------------------
    # 14. Bundled example passes the standalone validator
    # -----------------------------------------------------------------
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $validatorOutput = & $powerShellPath -NoProfile -File $validatorPath -DataFile $examplePath 2>&1 |
            Out-String
        $validatorExit = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    Assert-Condition ($validatorExit -eq 0) `
        "The bundled example data failed validation. Output: $validatorOutput"
    Write-Host 'Passed: bundled example data passes the standalone validator'
    $passed++

    # -----------------------------------------------------------------
    # 15. Schema and authoritative validator do not drift
    # -----------------------------------------------------------------
    $schema = [System.IO.File]::ReadAllText($schemaPath) | ConvertFrom-Json
    $contract = Get-CrowBusinessRuleContract

    function Assert-SetsMatch {
        param(
            [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Actual,
            [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Expected,
            [Parameter(Mandatory)][string]$Message
        )

        $left = @($Actual | Sort-Object) -join ','
        $right = @($Expected | Sort-Object) -join ','
        if ($left -ne $right) {
            throw "$Message. Schema: [$left]. Validator: [$right]."
        }
    }

    Assert-SetsMatch -Actual $schema.required -Expected $contract.RootRequired `
        -Message 'Schema and validator disagree on required root properties'
    Assert-SetsMatch -Actual @($schema.properties.PSObject.Properties.Name) `
        -Expected @($contract.RootRequired + $contract.RootOptional) `
        -Message 'Schema and validator disagree on root properties'
    Assert-Condition ($schema.properties.schema_version.const -eq $contract.SchemaVersion) `
        'Schema and validator disagree on the supported schema version.'
    Assert-Condition ($schema.properties.generated.pattern -eq $contract.DatePattern) `
        'Schema and validator disagree on the generated-date pattern.'

    $definitionMap = @(
        @{ Name = 'application'; Required = 'ApplicationRequired'; Optional = 'ApplicationOptional' },
        @{ Name = 'documentationSource'; Required = 'SourceRequired'; Optional = 'SourceOptional' },
        @{ Name = 'documentationGap'; Required = 'GapRequired'; Optional = 'GapOptional' },
        @{ Name = 'facetGroup'; Required = 'GroupRequired'; Optional = 'GroupOptional' },
        @{ Name = 'facet'; Required = 'FacetRequired'; Optional = 'FacetOptional' },
        @{ Name = 'rule'; Required = 'RuleRequired'; Optional = 'RuleOptional' },
        @{ Name = 'citation'; Required = 'CitationRequired'; Optional = 'CitationOptional' },
        @{ Name = 'reconciliation'; Required = 'ReconciliationRequired'; Optional = 'ReconciliationOptional' },
        @{ Name = 'retirement'; Required = 'RetirementRequired'; Optional = 'RetirementOptional' },
        @{ Name = 'matchNote'; Required = 'MatchNoteRequired'; Optional = 'MatchNoteOptional' },
        @{ Name = 'diagram'; Required = 'DiagramRequired'; Optional = 'DiagramOptional' }
    )
    foreach ($definition in $definitionMap) {
        $node = $schema.'$defs'.($definition.Name)
        Assert-Condition ($null -ne $node) "Schema is missing the '$($definition.Name)' definition."
        Assert-Condition ($node.additionalProperties -eq $false) `
            "Schema definition '$($definition.Name)' must reject unknown properties."
        Assert-SetsMatch -Actual @($node.required) -Expected @($contract[$definition.Required]) `
            -Message "Schema and validator disagree on required properties of '$($definition.Name)'"
        Assert-SetsMatch -Actual @($node.properties.PSObject.Properties.Name) `
            -Expected @($contract[$definition.Required] + $contract[$definition.Optional]) `
            -Message "Schema and validator disagree on the properties of '$($definition.Name)'"
    }

    Assert-SetsMatch -Actual @($schema.'$defs'.rule.properties.category.enum) `
        -Expected $contract.Categories `
        -Message 'Schema and validator disagree on rule categories'
    Assert-SetsMatch -Actual @($schema.'$defs'.rule.properties.status.enum) `
        -Expected $contract.RuleStatuses `
        -Message 'Schema and validator disagree on rule statuses'
    Assert-SetsMatch -Actual @($schema.'$defs'.reconciliation.properties.classification.enum) `
        -Expected $contract.Classifications `
        -Message 'Schema and validator disagree on reconciliation classifications'
    Assert-SetsMatch -Actual @($schema.'$defs'.documentationSource.properties.kind.enum) `
        -Expected $contract.SourceKinds `
        -Message 'Schema and validator disagree on documentation source kinds'
    Assert-SetsMatch -Actual @($schema.'$defs'.documentationSource.properties.status.enum) `
        -Expected $contract.SourceStatuses `
        -Message 'Schema and validator disagree on documentation source statuses'

    $patternMap = @(
        @{ Path = $schema.'$defs'.rule.properties.id.pattern; Expected = $contract.RuleIdPattern; Name = 'rule id' },
        @{ Path = $schema.'$defs'.documentationSource.properties.id.pattern; Expected = $contract.SourceIdPattern; Name = 'documentation source id' },
        @{ Path = $schema.'$defs'.facetGroup.properties.id.pattern; Expected = $contract.GroupIdPattern; Name = 'facet group id' },
        @{ Path = $schema.'$defs'.facet.properties.id.pattern; Expected = $contract.FacetIdPattern; Name = 'facet id' },
        @{ Path = $schema.'$defs'.diagram.properties.id.pattern; Expected = $contract.DiagramIdPattern; Name = 'diagram id' },
        @{ Path = $schema.'$defs'.citation.properties.commit.pattern; Expected = $contract.CommitPattern; Name = 'citation commit' },
        @{ Path = $schema.'$defs'.citation.properties.path.pattern; Expected = $contract.CitationPathPattern; Name = 'citation path' },
        @{ Path = $schema.'$defs'.application.properties.commit.pattern; Expected = $contract.CommitPattern; Name = 'application commit' },
        @{ Path = $schema.'$defs'.retirement.properties.retired_on.pattern; Expected = $contract.DatePattern; Name = 'retirement date' }
    )
    foreach ($pattern in $patternMap) {
        Assert-Condition ($pattern.Path -eq $pattern.Expected) `
            "Schema and validator disagree on the $($pattern.Name) pattern."
    }
    Write-Host 'Passed: schema and authoritative validator do not drift'
    $passed++

    Write-Host "Crow business-rule tests passed: $passed case(s)."
    exit 0
}
catch {
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 1
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
