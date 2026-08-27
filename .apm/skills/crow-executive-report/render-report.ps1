<#
.SYNOPSIS
  Renders executive-report.html from a template + JSON data file.
  All chart math (arc lengths, percentages, bar widths) is computed here
  so the LLM only emits data values, not markup.

.DESCRIPTION
  Reads the HTML template, injects minified CSS from executive-report.min.css,
  substitutes scalar placeholders, expands repeating sections (findings,
  tech_debt, stride, owasp), computes all derived values (percentages,
  SVG arc lengths), and writes the final self-contained HTML.

.PARAMETER DataFile
  Path to the JSON data file (report-data.json).

.PARAMETER OutputFile
  Path to write the rendered HTML. Defaults to executive-report.html
  next to the data file.

.EXAMPLE
  .\render-report.ps1 -DataFile docs\report-data.json
  .\render-report.ps1 -DataFile docs\svc\report-data.json -OutputFile docs\svc\executive-report.html
#>
param(
    [Parameter(Mandatory)][string]$DataFile,
    [string]$OutputFile
)

$ErrorActionPreference = 'Stop'

# --- Resolve paths ---
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$templateFile = Join-Path $scriptDir 'executive-report.html'
$cssFile = Join-Path $scriptDir 'executive-report.min.css'

if (-not $OutputFile) {
    $OutputFile = Join-Path (Split-Path -Parent $DataFile) 'executive-report.html'
}

if (-not (Test-Path $templateFile)) { throw "Template not found: $templateFile" }
if (-not (Test-Path $DataFile)) { throw "Data file not found: $DataFile" }

# --- Load inputs ---
$data = Get-Content $DataFile -Raw | ConvertFrom-Json
$html = Get-Content $templateFile -Raw -Encoding UTF8

# --- Inject CSS ---
if (Test-Path $cssFile) {
    $css = Get-Content $cssFile -Raw -Encoding UTF8
    $html = $html -replace '(?s)<style>.*?</style>', "<style>$css</style>"
}

# --- Helper: risk class from risk level ---
function Get-RiskClass([string]$risk) {
    switch ($risk.ToUpper()) {
        'CRITICAL' { 'critical' }
        'HIGH'     { 'high' }
        'MODERATE' { 'moderate' }
        'MEDIUM'   { 'moderate' }
        'LOW'      { 'low' }
        'SECURE'   { 'secure' }
        default    { 'low' }
    }
}

# --- Helper: safe percentage ---
function Get-Pct([double]$count, [double]$total) {
    if ($total -le 0) { return 0 }
    [math]::Round(($count / $total) * 100, 1)
}

function ConvertTo-HtmlText($value) {
    [System.Net.WebUtility]::HtmlEncode([string]$value)
}

function ConvertTo-RegexReplacedText([string]$inputText, [string]$pattern, [string]$replacement) {
    [regex]::Replace(
        $inputText,
        $pattern,
        [System.Text.RegularExpressions.MatchEvaluator] { param($match) $replacement }
    )
}

# --- Compute derived values ---
$total = [int]($data.critical_count + $data.high_count + $data.medium_count + $data.low_count + $data.informational_count)
$circ = 251.2  # 2 * pi * 40

$critArc   = if ($total -gt 0) { [math]::Round(($data.critical_count / $total) * $circ, 2) } else { 0 }
$highArc   = if ($total -gt 0) { [math]::Round(($data.high_count / $total) * $circ, 2) } else { 0 }
$medArc    = if ($total -gt 0) { [math]::Round(($data.medium_count / $total) * $circ, 2) } else { 0 }
$lowArc    = if ($total -gt 0) { [math]::Round(($data.low_count / $total) * $circ, 2) } else { 0 }
$critHighArc    = [math]::Round($critArc + $highArc, 2)
$critHighMedArc = [math]::Round($critArc + $highArc + $medArc, 2)

$confirmedPct = Get-Pct $data.confirmed_count $total
$probablePct  = Get-Pct $data.probable_count $total
$infoPct      = Get-Pct $data.informational_count $total

$totalDeps = [int]($data.total_deps)
$depsHealthyPct     = if ($totalDeps -gt 0) { Get-Pct ($totalDeps - $data.outdated_deps - $data.vulnerable_deps) $totalDeps } else { 100 }
$depsOutdatedPct    = Get-Pct $data.outdated_deps $totalDeps
$depsVulnerablePct  = Get-Pct $data.vulnerable_deps $totalDeps

$totalEntryPoints = if ($null -ne $data.coverage_gaps -and $null -ne $data.coverage_pct) {
    if ($data.coverage_pct -gt 0 -and $data.coverage_pct -lt 100) {
        [math]::Round($data.coverage_gaps / (1 - ($data.coverage_pct / 100)), 0)
    } else { $data.coverage_gaps }
} else { 0 }
$coveragePct = if ($data.PSObject.Properties['coverage_pct']) { $data.coverage_pct } else {
    if ($totalEntryPoints -gt 0) { Get-Pct ($totalEntryPoints - $data.coverage_gaps) $totalEntryPoints } else { 100 }
}

# --- OWASP bar chart: compute percentages relative to max ---
$owaspCats = @('A01','A02','A03','A04','A05','A06','A07','A08','A09','A10')
$owaspNames = @{
    A01='Broken Access Control'; A02='Security Misconfiguration'; A03='Supply Chain Failures'
    A04='Cryptographic Failures'; A05='Injection'; A06='Insecure Design'
    A07='Authentication Failures'; A08='Integrity Failures'; A09='Logging Failures'
    A10='Exception Handling'
}
$owaspColors = @{
    A01='var(--critical)'; A02='var(--high)'; A03='var(--high)'; A04='var(--medium)'
    A05='var(--critical)'; A06='var(--medium)'; A07='var(--high)'; A08='var(--medium)'
    A09='var(--medium)'; A10='var(--medium)'
}

# Build OWASP counts from data.owasp object or default to 0
$owaspCounts = @{}
foreach ($cat in $owaspCats) {
    $owaspCounts[$cat] = 0
    if ($data.PSObject.Properties['owasp'] -and $data.owasp.PSObject.Properties[$cat]) {
        $owaspCounts[$cat] = [int]$data.owasp.$cat
    }
}
$owaspMax = ($owaspCounts.Values | Measure-Object -Maximum).Maximum
if ($owaspMax -le 0) { $owaspMax = 1 }

# Build OWASP bar rows HTML
$owaspHtml = ""
foreach ($cat in $owaspCats) {
    $cnt = $owaspCounts[$cat]
    $pct = Get-Pct $cnt $owaspMax
    $color = $owaspColors[$cat]
    $name = $owaspNames[$cat]
    $owaspHtml += @"
  <div class="bar-row">
    <span class="bar-label">$cat</span>
    <div class="bar-track">
      <div class="bar-fill" style="width:${pct}%; background:${color};"></div>
      <span class="bar-value">$cnt &mdash; $name</span>
    </div>
  </div>`n
"@
}

# --- Build findings table rows ---
$findingsHtml = ""
if ($data.PSObject.Properties['findings']) {
    foreach ($f in $data.findings) {
        $sevClass = Get-RiskClass $f.severity
        $findingsHtml += @"
    <tr>
      <td>$(ConvertTo-HtmlText $f.title)</td>
      <td><span class="risk-badge $sevClass">$(ConvertTo-HtmlText $f.severity)</span></td>
      <td>$(ConvertTo-HtmlText $f.classification)</td>
      <td>$(ConvertTo-HtmlText $f.business_risk)</td>
      <td>$(ConvertTo-HtmlText $f.action)</td>
    </tr>`n
"@
    }
}

# --- Build tech debt table rows ---
$techDebtHtml = ""
if ($data.PSObject.Properties['tech_debt']) {
    foreach ($t in $data.tech_debt) {
        $riskClass = Get-RiskClass $t.risk
        $techDebtHtml += @"
    <tr>
      <td>$(ConvertTo-HtmlText $t.component)</td>
      <td>$(ConvertTo-HtmlText $t.category)</td>
      <td><span class="risk-badge $riskClass">$(ConvertTo-HtmlText $t.risk)</span></td>
      <td>$(ConvertTo-HtmlText $t.impact)</td>
      <td>$(ConvertTo-HtmlText $t.action)</td>
    </tr>`n
"@
    }
}

# --- Build STRIDE heatmap rows ---
# STRIDE cells use cell-high/cell-medium/cell-low (not cell-moderate like risk badges)
function Get-StrideCellClass([string]$level) {
    switch ($level.ToUpper()) {
        'HIGH'   { 'cell-high' }
        'MEDIUM' { 'cell-medium' }
        'LOW'    { 'cell-low' }
        default  { 'cell-low' }
    }
}
$strideHtml = ""
if ($data.PSObject.Properties['stride']) {
    foreach ($s in $data.stride) {
        $strideHtml += "    <tr>`n      <td>$(ConvertTo-HtmlText $s.component)</td>`n"
        foreach ($dim in @('S','T','R','I','D','E')) {
            $val = $s.$dim
            $cls = Get-StrideCellClass $val
            $strideHtml += "      <td class=`"$cls`">$(ConvertTo-HtmlText $val)</td>`n"
        }
        $strideHtml += "    </tr>`n"
    }
}

# --- Replace repeating sections ---
# OWASP bars
$html = ConvertTo-RegexReplacedText $html '(?s)<!-- Repeat for each OWASP.*?</div>\s*</div>\s*\n\s*</div>' "$owaspHtml</div>"
# Findings rows
$html = ConvertTo-RegexReplacedText $html '(?s)<!-- Repeat row per finding -->\s*<tr>.*?</tr>' $findingsHtml.TrimEnd()
# Tech debt rows (match the single template row)
$html = ConvertTo-RegexReplacedText $html '(?s)<tr>\s*<td>\{\{TECH_DEBT_COMPONENT\}\}.*?</tr>' $techDebtHtml.TrimEnd()
# STRIDE rows
$html = ConvertTo-RegexReplacedText $html '(?s)<!-- Repeat per component.*?<tr>\s*<td>\{\{COMPONENT_NAME\}\}.*?</tr>' $strideHtml.TrimEnd()

# --- Replace scalar placeholders ---
$scalars = @{
    'APPLICATION_NAME'     = $data.application_name
    'APPLICATION_ACRONYM'  = $data.application_acronym
    'REPORT_DATE'          = $data.report_date
    'OVERALL_RISK'         = $data.overall_risk
    'OVERALL_RISK_CLASS'   = Get-RiskClass $data.overall_risk
    'QUALITY_GATE_STATUS'  = $data.quality_gate_status
    'CRITICAL_COUNT'       = $data.critical_count
    'HIGH_COUNT'           = $data.high_count
    'MEDIUM_COUNT'         = $data.medium_count
    'LOW_COUNT'            = $data.low_count
    'INFO_COUNT'           = $data.informational_count
    'TOTAL_FINDINGS'       = $total
    'CONFIRMED_COUNT'      = $data.confirmed_count
    'PROBABLE_COUNT'       = $data.probable_count
    'COVERAGE_GAPS'        = $data.coverage_gaps
    'CRITICAL_ARC'         = $critArc
    'HIGH_ARC'             = $highArc
    'MEDIUM_ARC'           = $medArc
    'LOW_ARC'              = $lowArc
    'CRIT_HIGH_ARC'        = $critHighArc
    'CRIT_HIGH_MED_ARC'    = $critHighMedArc
    'CONFIRMED_PCT'        = $confirmedPct
    'PROBABLE_PCT'         = $probablePct
    'INFO_PCT'             = $infoPct
    'TOTAL_DEPS'           = $data.total_deps
    'OUTDATED_DEPS'        = $data.outdated_deps
    'VULNERABLE_DEPS'      = $data.vulnerable_deps
    'ABANDONED_DEPS'       = $data.abandoned_deps
    'DEPS_HEALTHY_PCT'     = $depsHealthyPct
    'DEPS_OUTDATED_PCT'    = $depsOutdatedPct
    'DEPS_VULNERABLE_PCT'  = $depsVulnerablePct
    'COVERAGE_PCT'         = $coveragePct
    'EXECUTIVE_BRIEF'      = $data.executive_brief
    'TECH_STACK_SUMMARY'   = $data.tech_stack_summary
    'ARCH_PATTERN'         = $data.arch_pattern
    'DEPLOYMENT_MODEL'     = $data.deployment_model
    'RESILIENCE_SUMMARY'   = $data.resilience_summary
    'P1_ACTIONS'           = $data.p1_actions
    'P2_ACTIONS'           = $data.p2_actions
    'P3_ACTIONS'           = $data.p3_actions
    'SECURITY_DOC_PATH'    = $data.security_doc_path
    'ARCHITECTURE_DOC_PATH'= $data.architecture_doc_path
}

foreach ($key in $scalars.Keys) {
    $html = $html.Replace("{{$key}}", (ConvertTo-HtmlText $scalars[$key]))
}

# --- Write output ---
$html | Set-Content $OutputFile -Encoding UTF8 -NoNewline
Write-Host "Rendered: $OutputFile" -ForegroundColor Green
