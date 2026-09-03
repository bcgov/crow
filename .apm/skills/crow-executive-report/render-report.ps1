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
$data = Get-Content $DataFile -Raw -Encoding UTF8 | ConvertFrom-Json
$html = Get-Content $templateFile -Raw -Encoding UTF8

# --- Inject CSS ---
if (Test-Path $cssFile) {
    $css = Get-Content $cssFile -Raw -Encoding UTF8
    $html = $html -replace '(?s)<style>.*?</style>', "<style>$css</style>"
}

# --- Helper: risk class from risk level ---
function Get-RiskClass([string]$risk) {
    $normalizedRisk = if ($null -eq $risk) { '' } else { $risk.Trim().ToUpperInvariant() }
    switch ($normalizedRisk) {
        'CRITICAL'          { 'critical' }
        'BLOCKER'           { 'critical' }
        'HIGH'              { 'high' }
        'MODERATE'          { 'moderate' }
        'MEDIUM'            { 'moderate' }
        'LOW'               { 'low' }
        'SECURE'            { 'secure' }
        default             { 'low' }
    }
}

# --- Helper: safe percentage ---
function Get-Pct([double]$count, [double]$total) {
    if ($total -le 0) { return 0 }
    [math]::Min(100, [math]::Max(0, [math]::Round(($count / $total) * 100, 1)))
}

function ConvertTo-HtmlText($value) {
    [System.Net.WebUtility]::HtmlEncode([string]$value)
}

function Get-ReportProperty($object, [string]$propertyName) {
    if ($null -eq $object) { return $null }
    $property = $object.PSObject.Properties[$propertyName]
    if ($null -eq $property) { return $null }
    $property.Value
}

function ConvertTo-OptionalHtmlText($value) {
    if ($null -eq $value) { return 'Unknown' }
    $text = [Convert]::ToString($value, [Globalization.CultureInfo]::InvariantCulture)
    if ([string]::IsNullOrWhiteSpace($text)) { return 'Unknown' }
    ConvertTo-HtmlText $text
}

function ConvertTo-NonNegativeInteger($value, [string]$fieldName) {
    $parsed = 0L
    $text = [Convert]::ToString($value, [Globalization.CultureInfo]::InvariantCulture)
    if (-not [long]::TryParse(
        $text,
        [Globalization.NumberStyles]::Integer,
        [Globalization.CultureInfo]::InvariantCulture,
        [ref]$parsed
    ) -or $parsed -lt 0) {
        throw "Field '$fieldName' must be a non-negative integer."
    }
    $parsed
}

function ConvertTo-Percentage($value, [string]$fieldName) {
    $parsed = 0.0
    $text = [Convert]::ToString($value, [Globalization.CultureInfo]::InvariantCulture)
    if (-not [double]::TryParse(
        $text,
        [Globalization.NumberStyles]::Float,
        [Globalization.CultureInfo]::InvariantCulture,
        [ref]$parsed
    ) -or [double]::IsNaN($parsed) -or [double]::IsInfinity($parsed)) {
        throw "Field '$fieldName' must be a finite number."
    }
    [math]::Min(100, [math]::Max(0, $parsed))
}

function ConvertTo-InvariantNumber($value) {
    if ($value -isnot [IFormattable]) {
        throw "Numeric placeholder value '$value' is not formattable."
    }
    $value.ToString($null, [Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-RegexReplacedText([string]$inputText, [string]$pattern, [string]$replacement) {
    [regex]::Replace(
        $inputText,
        $pattern,
        [System.Text.RegularExpressions.MatchEvaluator] { param($match) $replacement }
    )
}

# --- Compute derived values ---
$criticalCount = ConvertTo-NonNegativeInteger $data.critical_count 'critical_count'
$highCount = ConvertTo-NonNegativeInteger $data.high_count 'high_count'
$mediumCount = ConvertTo-NonNegativeInteger $data.medium_count 'medium_count'
$lowCount = ConvertTo-NonNegativeInteger $data.low_count 'low_count'
$informationalCount = ConvertTo-NonNegativeInteger $data.informational_count 'informational_count'
$confirmedCount = ConvertTo-NonNegativeInteger $data.confirmed_count 'confirmed_count'
$probableCount = ConvertTo-NonNegativeInteger $data.probable_count 'probable_count'
$coverageGaps = ConvertTo-NonNegativeInteger $data.coverage_gaps 'coverage_gaps'
$totalDeps = ConvertTo-NonNegativeInteger $data.total_deps 'total_deps'
$outdatedDeps = ConvertTo-NonNegativeInteger $data.outdated_deps 'outdated_deps'
$vulnerableDeps = ConvertTo-NonNegativeInteger $data.vulnerable_deps 'vulnerable_deps'
$abandonedDeps = ConvertTo-NonNegativeInteger $data.abandoned_deps 'abandoned_deps'

$total = $criticalCount + $highCount + $mediumCount + $lowCount + $informationalCount
$circ = 251.2  # 2 * pi * 40

$critArc   = if ($total -gt 0) { [math]::Round(($criticalCount / $total) * $circ, 2) } else { 0 }
$highArc   = if ($total -gt 0) { [math]::Round(($highCount / $total) * $circ, 2) } else { 0 }
$medArc    = if ($total -gt 0) { [math]::Round(($mediumCount / $total) * $circ, 2) } else { 0 }
$lowArc    = if ($total -gt 0) { [math]::Round(($lowCount / $total) * $circ, 2) } else { 0 }
$critHighArc    = [math]::Round($critArc + $highArc, 2)
$critHighMedArc = [math]::Round($critArc + $highArc + $medArc, 2)

$confirmedPct = Get-Pct $confirmedCount $total
$probablePct  = Get-Pct $probableCount $total
$infoPct      = Get-Pct $informationalCount $total

$depsHealthyPct     = if ($totalDeps -gt 0) { Get-Pct ($totalDeps - $outdatedDeps - $vulnerableDeps) $totalDeps } else { 100 }
$depsOutdatedPct    = Get-Pct $outdatedDeps $totalDeps
$depsVulnerablePct  = Get-Pct $vulnerableDeps $totalDeps

$coveragePct = if ($data.PSObject.Properties['coverage_pct']) {
    ConvertTo-Percentage $data.coverage_pct 'coverage_pct'
} else {
    100
}
$totalEntryPoints = if ($data.PSObject.Properties['coverage_pct']) {
    if ($coveragePct -gt 0 -and $coveragePct -lt 100) {
        [math]::Round($coverageGaps / (1 - ($coveragePct / 100)), 0)
    } else { $coverageGaps }
} else { 0 }
if (-not $data.PSObject.Properties['coverage_pct']) {
    $coveragePct = if ($totalEntryPoints -gt 0) { Get-Pct ($totalEntryPoints - $coverageGaps) $totalEntryPoints } else { 100 }
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
        $owaspCounts[$cat] = ConvertTo-NonNegativeInteger $data.owasp.$cat "owasp.$cat"
    }
}
$owaspMax = ($owaspCounts.Values | Measure-Object -Maximum).Maximum
if ($owaspMax -le 0) { $owaspMax = 1 }

# Build OWASP bar rows HTML
$owaspHtml = ""
foreach ($cat in $owaspCats) {
    $cnt = $owaspCounts[$cat]
    $pct = Get-Pct $cnt $owaspMax
    $cntText = ConvertTo-InvariantNumber $cnt
    $pctText = ConvertTo-InvariantNumber $pct
    $color = $owaspColors[$cat]
    $name = $owaspNames[$cat]
    $owaspHtml += @"
  <div class="bar-row">
    <span class="bar-label">$cat</span>
    <div class="bar-track">
      <div class="bar-fill" style="width:${pctText}%; background:${color};"></div>
      <span class="bar-value">$cntText &mdash; $name</span>
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

# --- Build optional platform alignment section ---
$platformAlignment = Get-ReportProperty $data 'platform_alignment'
$platformMetrics = Get-ReportProperty $data 'platform_metrics'
$platformEvidence = Get-ReportProperty $platformAlignment 'evidence'
$metricsEvidence = Get-ReportProperty $platformMetrics 'evidence'
$hasPlatformEvidence = (
    -not [string]::IsNullOrWhiteSpace([Convert]::ToString($platformEvidence)) -or
    -not [string]::IsNullOrWhiteSpace([Convert]::ToString($metricsEvidence))
)
$platformHtml = ""
if ($hasPlatformEvidence) {
    $platformHtml = @"
<h2>Platform Alignment</h2>
<p class="section-note">Evidence-backed platform role, reuse, data responsibility, contract, and dependency behavior. Unsupported values are shown as Unknown.</p>
<div class="flex-row">
  <div class="flex-col-half">
    <table class="data-table">
      <tbody>
        <tr><th>Role</th><td>$(ConvertTo-OptionalHtmlText (Get-ReportProperty $platformAlignment 'role'))</td></tr>
        <tr><th>Confidence</th><td>$(ConvertTo-OptionalHtmlText (Get-ReportProperty $platformAlignment 'confidence'))</td></tr>
        <tr><th>Known Consumers</th><td>$(ConvertTo-OptionalHtmlText (Get-ReportProperty $platformAlignment 'consumer_count'))</td></tr>
        <tr><th>Reuse Decision</th><td>$(ConvertTo-OptionalHtmlText (Get-ReportProperty $platformAlignment 'reuse_decision'))</td></tr>
        <tr><th>Data Custodian</th><td>$(ConvertTo-OptionalHtmlText (Get-ReportProperty $platformAlignment 'data_custodian'))</td></tr>
        <tr><th>Data Sharing</th><td>$(ConvertTo-OptionalHtmlText (Get-ReportProperty $platformAlignment 'data_sharing_spectrum'))</td></tr>
      </tbody>
    </table>
  </div>
  <div class="flex-col-half">
    <table class="data-table">
      <tbody>
        <tr><th>Contract Owner</th><td>$(ConvertTo-OptionalHtmlText (Get-ReportProperty $platformAlignment 'contract_owner'))</td></tr>
        <tr><th>Contract Versioning</th><td>$(ConvertTo-OptionalHtmlText (Get-ReportProperty $platformAlignment 'contract_versioning'))</td></tr>
        <tr><th>Degradation Behavior</th><td>$(ConvertTo-OptionalHtmlText (Get-ReportProperty $platformAlignment 'degradation_behavior'))</td></tr>
        <tr><th>Shared Dependencies</th><td>$(ConvertTo-OptionalHtmlText (Get-ReportProperty $platformMetrics 'shared_dependency_count'))</td></tr>
        <tr><th>Consumers Measured</th><td>$(ConvertTo-OptionalHtmlText (Get-ReportProperty $platformMetrics 'known_consumer_count'))</td></tr>
        <tr><th>Contracts With Owners</th><td>$(ConvertTo-OptionalHtmlText (Get-ReportProperty $platformMetrics 'contracts_with_owner_count'))</td></tr>
        <tr><th>Fallback Scenarios Tested</th><td>$(ConvertTo-OptionalHtmlText (Get-ReportProperty $platformMetrics 'fallback_scenarios_tested_count'))</td></tr>
      </tbody>
    </table>
  </div>
</div>
<p class="section-note"><strong>Evidence:</strong> $(ConvertTo-OptionalHtmlText $(if ($platformEvidence) { $platformEvidence } else { $metricsEvidence }))</p>
"@
}

# --- Build optional Zero Trust posture section ---
$zeroTrust = Get-ReportProperty $data 'zero_trust_posture'
$zeroTrustEvidence = Get-ReportProperty $zeroTrust 'evidence'
$zeroTrustHtml = ""
if (-not [string]::IsNullOrWhiteSpace([Convert]::ToString($zeroTrustEvidence))) {
    $zeroTrustHtml = @"
<h2>Zero Trust Posture</h2>
<p class="section-note">Evidence-backed resource protection summary. This is not an enterprise maturity score.</p>
<table class="data-table">
  <tbody>
    <tr><th>Protected Resources</th><td>$(ConvertTo-OptionalHtmlText (Get-ReportProperty $zeroTrust 'protected_resources'))</td></tr>
    <tr><th>Enforcement Points</th><td>$(ConvertTo-OptionalHtmlText (Get-ReportProperty $zeroTrust 'enforcement_points'))</td></tr>
    <tr><th>Least Privilege</th><td>$(ConvertTo-OptionalHtmlText (Get-ReportProperty $zeroTrust 'least_privilege'))</td></tr>
    <tr><th>Revocation and Expiry</th><td>$(ConvertTo-OptionalHtmlText (Get-ReportProperty $zeroTrust 'revocation_and_expiry'))</td></tr>
    <tr><th>Exceptions and Degradation</th><td>$(ConvertTo-OptionalHtmlText (Get-ReportProperty $zeroTrust 'exceptions_and_degradation'))</td></tr>
    <tr><th>Telemetry</th><td>$(ConvertTo-OptionalHtmlText (Get-ReportProperty $zeroTrust 'telemetry'))</td></tr>
    <tr><th>Confidence</th><td>$(ConvertTo-OptionalHtmlText (Get-ReportProperty $zeroTrust 'confidence'))</td></tr>
  </tbody>
</table>
<p class="section-note"><strong>Evidence:</strong> $(ConvertTo-OptionalHtmlText $zeroTrustEvidence)</p>
"@
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
# Optional platform alignment (omitted when no evidence is supplied)
$html = $html.Replace('{{PLATFORM_ALIGNMENT_SECTION}}', $platformHtml)
$html = $html.Replace('{{ZERO_TRUST_POSTURE_SECTION}}', $zeroTrustHtml)

# --- Replace scalar placeholders ---
$textScalars = @{
    'APPLICATION_NAME'     = $data.application_name
    'APPLICATION_ACRONYM'  = $data.application_acronym
    'REPORT_DATE'          = $data.report_date
    'OVERALL_RISK'         = $data.overall_risk
    'QUALITY_GATE_STATUS'  = $data.quality_gate_status
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

$tokenScalars = @{
    'OVERALL_RISK_CLASS' = Get-RiskClass $data.overall_risk
}

$numericScalars = @{
    'CRITICAL_COUNT'      = $criticalCount
    'HIGH_COUNT'          = $highCount
    'MEDIUM_COUNT'        = $mediumCount
    'LOW_COUNT'           = $lowCount
    'INFO_COUNT'          = $informationalCount
    'TOTAL_FINDINGS'      = $total
    'CONFIRMED_COUNT'     = $confirmedCount
    'PROBABLE_COUNT'      = $probableCount
    'COVERAGE_GAPS'       = $coverageGaps
    'CRITICAL_ARC'        = $critArc
    'HIGH_ARC'            = $highArc
    'MEDIUM_ARC'          = $medArc
    'LOW_ARC'             = $lowArc
    'CRIT_HIGH_ARC'       = $critHighArc
    'CRIT_HIGH_MED_ARC'   = $critHighMedArc
    'CONFIRMED_PCT'       = $confirmedPct
    'PROBABLE_PCT'        = $probablePct
    'INFO_PCT'            = $infoPct
    'TOTAL_DEPS'          = $totalDeps
    'OUTDATED_DEPS'       = $outdatedDeps
    'VULNERABLE_DEPS'     = $vulnerableDeps
    'ABANDONED_DEPS'      = $abandonedDeps
    'DEPS_HEALTHY_PCT'    = $depsHealthyPct
    'DEPS_OUTDATED_PCT'   = $depsOutdatedPct
    'DEPS_VULNERABLE_PCT' = $depsVulnerablePct
    'COVERAGE_PCT'        = $coveragePct
}

foreach ($key in $textScalars.Keys) {
    $html = $html.Replace("{{$key}}", (ConvertTo-HtmlText $textScalars[$key]))
}
foreach ($key in $tokenScalars.Keys) {
    $html = $html.Replace("{{$key}}", $tokenScalars[$key])
}
foreach ($key in $numericScalars.Keys) {
    $html = $html.Replace("{{$key}}", (ConvertTo-InvariantNumber $numericScalars[$key]))
}

# --- Write output ---
$html | Set-Content $OutputFile -Encoding UTF8 -NoNewline
Write-Host "Rendered: $OutputFile" -ForegroundColor Green
