<#
.SYNOPSIS
  Renders business-rules.md and business-rules.html from a snippet-free
  business-rules-data.json file.

.DESCRIPTION
  Validates the report data with the authoritative Crow business-rule contract,
  enforces the identifier ledger against the previously committed data file,
  pre-renders every Mermaid diagram to inline SVG with a preinstalled Mermaid
  CLI, sanitizes the rendered SVG, builds both documents in memory, verifies the
  HTML is self-contained, and only then publishes the outputs as a pair. Any
  failure leaves the target documents unchanged.

  The ledger comparison is mandatory for a regeneration: when either output
  document already exists, -PreviousDataFile must be supplied. First-time
  generation may omit it.

  The renderer never downloads or executes a package at run time: supply
  -MermaidCliPath or install mmdc once.

.PARAMETER DataFile
  Path to business-rules-data.json.

.PARAMETER OutputDirectory
  Directory that receives business-rules.md and business-rules.html. Defaults to
  the directory containing the data file (normally the target repository's
  docs/ directory).

.PARAMETER MermaidCliPath
  Path to a preinstalled Mermaid CLI (mmdc). When omitted, mmdc is discovered on
  PATH. Required only when the data file declares diagrams.

.PARAMETER PreviousDataFile
  Path to the previously committed business-rules-data.json, used as the
  identifier ledger. Required whenever business-rules.md or business-rules.html
  already exists in the output directory: that run is a regeneration, and the
  renderer refuses it without the ledger rather than replacing a report whose
  identifiers were never compared. Only first-time generation may omit it.
  Extract it with Export-PreviousBusinessRuleData.ps1.

.PARAMETER AllowRetiredRuleReactivation
  Explicit override that permits a retired identifier to become active again.
  Requires -PreviousDataFile, reports the accepted risk, and is only correct when
  the identical rule was restored in the implementation.

.EXAMPLE
  ./render-business-rules.ps1 -DataFile ../../../docs/business-rules-data.json

.EXAMPLE
  ./render-business-rules.ps1 -DataFile docs/business-rules-data.json -MermaidCliPath C:\tools\mmdc.cmd

.EXAMPLE
  ./Export-PreviousBusinessRuleData.ps1 -Destination previous-business-rules-data.json
  ./render-business-rules.ps1 -DataFile docs/business-rules-data.json -PreviousDataFile previous-business-rules-data.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DataFile,
    [string]$OutputDirectory,
    [string]$MermaidCliPath,
    [string]$PreviousDataFile,
    [switch]$AllowRetiredRuleReactivation
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'CrowBusinessRules.psm1') -Force

$skillRoot = Split-Path -Parent $PSScriptRoot
$templateRoot = Join-Path $skillRoot 'templates'
$assetRoot = Join-Path $skillRoot 'assets'
$markdownTemplatePath = Join-Path $templateRoot 'business-rules-template.md'
$htmlTemplatePath = Join-Path $templateRoot 'business-rules.html'
$cssPath = Join-Path $assetRoot 'business-rules.css'
$javaScriptPath = Join-Path $assetRoot 'business-rules.js'
$mermaidConfigPath = Join-Path $assetRoot 'mermaid-config.json'

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    'crow-business-rules-' + [guid]::NewGuid().ToString('N'))

$emDash = [string][char]0x2014

function Get-Text {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return '' }
    return [string]$Value
}

function Get-Items {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return @() }
    return @($Value)
}

function Resolve-MermaidCli {
    param([string]$RequestedPath)

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        if (Test-Path -LiteralPath $RequestedPath) {
            return (Resolve-Path -LiteralPath $RequestedPath).Path
        }
        throw ("-MermaidCliPath '$RequestedPath' does not exist. Provide the path to a " +
            'preinstalled Mermaid CLI (mmdc) executable.')
    }

    # Only executables are usable here. Get-Command without -CommandType would
    # resolve npm's Windows shim layout to the PowerShell wrapper mmdc.ps1 and
    # hide the mmdc.cmd installed beside it, so the CLI is looked up as an
    # application. On Windows, prefer a PATHEXT extension so the extensionless
    # shell shim is not selected.
    $candidates = @(Get-Command 'mmdc' -CommandType Application -ErrorAction SilentlyContinue)
    if ($candidates.Count -gt 0) {
        $pathExtensions = @()
        if (-not [string]::IsNullOrWhiteSpace($env:PATHEXT)) {
            $pathExtensions = @($env:PATHEXT -split ';' |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                ForEach-Object { $_.Trim().ToLowerInvariant() })
        }
        if ($pathExtensions.Count -gt 0) {
            $preferred = @($candidates | Where-Object {
                    $pathExtensions -contains [System.IO.Path]::GetExtension($_.Source).ToLowerInvariant()
                })
            if ($preferred.Count -gt 0) { $candidates = $preferred }
        }
        return $candidates[0].Source
    }


    throw ('Mermaid CLI (mmdc) was not found. Install it once with ' +
        "'npm install -g @mermaid-js/mermaid-cli', or pass -MermaidCliPath <path to mmdc>. " +
        'This renderer never invokes npx or downloads packages at run time, so diagrams ' +
        'cannot be rendered until mmdc is available. No output files were written.')
}

function Invoke-MermaidCli {
    param(
        [Parameter(Mandatory)][string]$CliPath,
        [Parameter(Mandatory)][string]$InputPath,
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][string]$ConfigPath,
        [Parameter(Mandatory)][string]$SvgId,
        [Parameter(Mandatory)][string]$DiagramId
    )

    $arguments = @(
        '--input', $InputPath,
        '--output', $OutputPath,
        '--configFile', $ConfigPath,
        '--backgroundColor', 'transparent',
        '--svgId', $SvgId,
        '--quiet'
    )

    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $CliPath @arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }

    if ($null -ne $output) {
        foreach ($line in @($output)) { Write-Verbose ([string]$line) }
    }
    if ($exitCode -ne 0) {
        throw ("Mermaid rendering failed for diagram '$DiagramId' (exit code $exitCode). " +
            'No output files were written.')
    }
    if (-not (Test-Path -LiteralPath $OutputPath)) {
        throw ("Mermaid rendering produced no SVG for diagram '$DiagramId'. " +
            'No output files were written.')
    }
}

function Get-CitationLine {
    param([AllowNull()][object]$Citation)
    $line = Get-CrowProperty $Citation 'line'
    if ($null -eq $line) { return $null }
    return [Convert]::ToString($line, [Globalization.CultureInfo]::InvariantCulture)
}

$markdownDocument = $null
$htmlDocument = $null

try {
    foreach ($requiredAsset in @(
            $markdownTemplatePath, $htmlTemplatePath, $cssPath,
            $javaScriptPath, $mermaidConfigPath)) {
        if (-not (Test-Path -LiteralPath $requiredAsset)) {
            throw "Required skill asset is missing: $requiredAsset"
        }
    }
    if (-not (Test-Path -LiteralPath $DataFile)) {
        throw "Data file not found: $DataFile"
    }

    $dataPath = (Resolve-Path -LiteralPath $DataFile).Path
    if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
        $OutputDirectory = Split-Path -Parent $dataPath
    }
    if (-not (Test-Path -LiteralPath $OutputDirectory)) {
        throw "Output directory not found: $OutputDirectory"
    }
    $outputRoot = (Resolve-Path -LiteralPath $OutputDirectory).Path
    $markdownOutputPath = Join-Path $outputRoot 'business-rules.md'
    $htmlOutputPath = Join-Path $outputRoot 'business-rules.html'

    $rawData = [System.IO.File]::ReadAllText($dataPath)
    try {
        $data = $rawData | ConvertFrom-Json
    }
    catch {
        throw "business-rules-data.json is not valid JSON: $($_.Exception.Message)"
    }

    $validationErrors = @(Test-CrowBusinessRuleData -Data $data)
    if ($validationErrors.Count -gt 0) {
        foreach ($validationError in $validationErrors) {
            Write-Error $validationError -ErrorAction Continue
        }
        throw ("business-rules-data.json failed validation with $($validationErrors.Count) " +
            'error(s). No output files were written.')
    }

    # ---------------------------------------------------------------------
    # Identifier ledger: enforced here as well, so a regeneration cannot skip
    # the comparison by calling the renderer directly. A run that would replace
    # an existing document is a regeneration and must supply the ledger; only
    # first-time generation may omit it.
    # ---------------------------------------------------------------------
    if ($AllowRetiredRuleReactivation -and [string]::IsNullOrWhiteSpace($PreviousDataFile)) {
        throw ('-AllowRetiredRuleReactivation only applies to a ledger comparison. ' +
            'Supply -PreviousDataFile with the previously committed data file. ' +
            'No output files were written.')
    }
    if ([string]::IsNullOrWhiteSpace($PreviousDataFile)) {
        $existingOutputs = @(
            @($markdownOutputPath, $htmlOutputPath) |
                Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
        if ($existingOutputs.Count -gt 0) {
            $existSuffix = if ($existingOutputs.Count -eq 1) { 'already exists' } else { 'already exist' }
            throw ("This is a regeneration: $($existingOutputs -join ' and ') $existSuffix. " +
                '-PreviousDataFile is required so the identifier ledger is enforced and a rule ' +
                'identifier cannot disappear, silently reactivate, or be reused. Extract the ' +
                'committed data file with Export-PreviousBusinessRuleData.ps1, for example ' +
                "'./Export-PreviousBusinessRuleData.ps1 -Destination previous-business-rules-data.json', " +
                'then re-run with -PreviousDataFile previous-business-rules-data.json. ' +
                'No output files were written.')
        }
    }
    else {
        if (-not (Test-Path -LiteralPath $PreviousDataFile)) {
            throw "The previous business-rules-data.json was not found: $PreviousDataFile"
        }
        $previousRaw = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $PreviousDataFile).Path)
        try {
            $previousData = $previousRaw | ConvertFrom-Json
        }
        catch {
            throw "The previous business-rules-data.json is not valid JSON: $($_.Exception.Message)"
        }
        $ledgerErrors = New-Object 'System.Collections.Generic.List[string]'
        $ledgerRisks = New-Object 'System.Collections.Generic.List[string]'
        Test-CrowBusinessRuleLedger -PreviousData $previousData -CurrentData $data `
            -AllowRetiredRuleReactivation:$AllowRetiredRuleReactivation `
            -Errors $ledgerErrors -Risks $ledgerRisks
        foreach ($ledgerRisk in $ledgerRisks) { Write-Warning $ledgerRisk }
        if ($ledgerErrors.Count -gt 0) {
            foreach ($ledgerError in $ledgerErrors) { Write-Error $ledgerError -ErrorAction Continue }
            throw ("The identifier ledger comparison failed with $($ledgerErrors.Count) error(s). " +
                'No output files were written.')
        }
    }

    $application = $data.application
    $applicationName = Get-Text $application.name
    $applicationAcronym = Get-Text (Get-CrowProperty $application 'acronym')
    $displayName = if ([string]::IsNullOrWhiteSpace($applicationAcronym)) {
        $applicationName
    }
    else {
        "$applicationName ($applicationAcronym)"
    }
    $scopeStatement = Get-Text $application.scope
    $scopeNote = Get-Text (Get-CrowProperty $application 'scope_note')
    $repository = Get-Text $application.repository
    $commit = Get-Text $application.commit
    $generated = Get-Text $data.generated

    $rules = @(Get-Items $data.rules)
    $diagrams = @(Get-Items $data.diagrams)
    $groups = @(Get-Items $data.facet_groups)
    $sources = @(Get-Items $data.documentation_sources)
    $openQuestions = @(Get-Items (Get-CrowProperty $data 'open_questions'))
    $gap = $data.documentation_gap

    $facetLabels = @{}
    $facetGroupLabels = @{}
    $facetDescriptions = @{}
    foreach ($group in $groups) {
        foreach ($facet in Get-Items $group.facets) {
            $facetLabels[$facet.id] = Get-Text $facet.label
            $facetGroupLabels[$facet.id] = Get-Text $group.label
            $facetDescriptions[$facet.id] = Get-Text (Get-CrowProperty $facet 'description')
        }
    }

    $facetCounts = @{}
    $classificationCounts = @{}
    $categoryCounts = @{}
    $activeCount = 0
    $retiredCount = 0
    foreach ($rule in $rules) {
        foreach ($facetRef in Get-Items $rule.facets) {
            if ($facetCounts.ContainsKey($facetRef)) { $facetCounts[$facetRef]++ }
            else { $facetCounts[$facetRef] = 1 }
        }
        $classification = Get-Text $rule.reconciliation.classification
        if ($classificationCounts.ContainsKey($classification)) { $classificationCounts[$classification]++ }
        else { $classificationCounts[$classification] = 1 }
        $category = Get-Text $rule.category
        if ($categoryCounts.ContainsKey($category)) { $categoryCounts[$category]++ }
        else { $categoryCounts[$category] = 1 }
        if ((Get-Text $rule.status) -eq 'retired') { $retiredCount++ } else { $activeCount++ }
    }

    # ---------------------------------------------------------------------
    # Diagrams: render, sanitize, and give each diagram a unique id prefix.
    # ---------------------------------------------------------------------
    $renderedDiagrams = @{}
    if ($diagrams.Count -gt 0) {
        $mermaidCli = Resolve-MermaidCli -RequestedPath $MermaidCliPath
        New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null
        foreach ($diagram in $diagrams) {
            $diagramId = Get-Text $diagram.id
            $inputPath = Join-Path $temporaryRoot "$diagramId.mmd"
            $outputPath = Join-Path $temporaryRoot "$diagramId.svg"
            $encoding = [System.Text.UTF8Encoding]::new($false)
            [System.IO.File]::WriteAllText(
                $inputPath,
                (Get-Text $diagram.mermaid).Replace("`r`n", "`n"),
                $encoding)

            Invoke-MermaidCli -CliPath $mermaidCli -InputPath $inputPath -OutputPath $outputPath `
                -ConfigPath $mermaidConfigPath -SvgId 'graph' -DiagramId $diagramId

            $svg = [System.IO.File]::ReadAllText($outputPath)
            $svg = [regex]::Replace($svg, '^\s*<\?xml[^>]*\?>\s*', '')
            $svgErrors = New-Object 'System.Collections.Generic.List[string]'
            Test-CrowRenderedSvg -Svg $svg -Path "Diagram '$diagramId'" -Errors $svgErrors
            if ($svgErrors.Count -gt 0) {
                foreach ($svgError in $svgErrors) { Write-Error $svgError -ErrorAction Continue }
                throw ("Rendered SVG for diagram '$diagramId' failed sanitization. " +
                    'No output files were written.')
            }
            $svg = ConvertTo-CrowPrefixedSvg -Svg $svg -Prefix "br-$diagramId-"
            $svg = Set-CrowSvgAccessibleName -Svg $svg `
                -LabelledBy "diagram-$diagramId-title diagram-$diagramId-description"
            $renderedDiagrams[$diagramId] = $svg.Trim()
        }
    }

    # ---------------------------------------------------------------------
    # Markdown document
    # ---------------------------------------------------------------------
    $markdownTemplate = [System.IO.File]::ReadAllText($markdownTemplatePath)

    $documentationRows = New-Object 'System.Collections.Generic.List[string]'
    foreach ($source in $sources) {
        $documentationRows.Add(('| {0} | {1} | {2} | {3} | {4} |' -f
            (ConvertTo-CrowMarkdownCell $source.id),
            (ConvertTo-CrowMarkdownCell $source.title),
            (ConvertTo-CrowMarkdownCell $source.kind),
            (ConvertTo-CrowMarkdownCell $source.status),
            (ConvertTo-CrowMarkdownCell $source.location)))
    }
    $documentationSection = if ($documentationRows.Count -gt 0) {
        @(
            '| Source | Title | Kind | Status | Location |'
            '|---|---|---|---|---|'
            ($documentationRows -join "`n")
        ) -join "`n"
    }
    else {
        'No guides, training material, or written specifications were available for this scope.'
    }
    if ($gap.present) {
        $documentationSection += "`n`n> **Documentation gap.** " +
            (ConvertTo-CrowMarkdownText $gap.summary) + ' ' +
            (ConvertTo-CrowMarkdownText $gap.coverage_impact)
    }

    $facetRows = New-Object 'System.Collections.Generic.List[string]'
    foreach ($group in $groups) {
        foreach ($facet in Get-Items $group.facets) {
            $count = 0
            if ($facetCounts.ContainsKey($facet.id)) { $count = $facetCounts[$facet.id] }
            $facetRows.Add(('| {0} | {1} | {2} | {3} |' -f
                (ConvertTo-CrowMarkdownCell $group.label),
                (ConvertTo-CrowMarkdownCell $facet.label),
                (ConvertTo-CrowMarkdownCell $facet.id),
                $count))
        }
    }
    $facetSection = @(
        '| Group | Facet | Identifier | Rules |'
        '|---|---|---|---|'
        ($facetRows -join "`n")
    ) -join "`n"

    $indexRows = New-Object 'System.Collections.Generic.List[string]'
    $ruleSections = New-Object 'System.Collections.Generic.List[string]'
    foreach ($rule in $rules) {
        $ruleId = Get-Text $rule.id
        $indexRows.Add(('| {0} | {1} | {2} | {3} | {4} |' -f
            (ConvertTo-CrowMarkdownCell $ruleId),
            (ConvertTo-CrowMarkdownCell $rule.title),
            (ConvertTo-CrowMarkdownCell $rule.category),
            (ConvertTo-CrowMarkdownCell $rule.status),
            (ConvertTo-CrowMarkdownCell $rule.reconciliation.classification)))

        $section = New-Object 'System.Collections.Generic.List[string]'
        $section.Add(('### {0} {1} {2}' -f
            (ConvertTo-CrowMarkdownCell $ruleId),
            $emDash,
            (ConvertTo-CrowMarkdownCell $rule.title)))
        $section.Add('')
        $section.Add(('- **Category:** {0}' -f (ConvertTo-CrowMarkdownCell $rule.category)))
        $section.Add(('- **Status:** {0}' -f (ConvertTo-CrowMarkdownCell $rule.status)))
        $section.Add(('- **Reconciliation:** {0}' -f
            (ConvertTo-CrowMarkdownCell $rule.reconciliation.classification)))
        $reconciliationNote = Get-Text (Get-CrowProperty $rule.reconciliation 'note')
        if (-not [string]::IsNullOrWhiteSpace($reconciliationNote)) {
            $section.Add(('- **Reconciliation note:** {0}' -f
                (ConvertTo-CrowMarkdownCell $reconciliationNote)))
        }
        $facetTexts = @(Get-Items $rule.facets | ForEach-Object {
            ConvertTo-CrowMarkdownCell ('{0}: {1}' -f $facetGroupLabels[$_], $facetLabels[$_])
        })
        $section.Add(('- **Facets:** {0}' -f ($facetTexts -join '; ')))
        $retirement = Get-CrowProperty $rule 'retirement'
        if ($null -ne $retirement) {
            $section.Add(('- **Retired on:** {0} {1} {2}' -f
                (ConvertTo-CrowMarkdownCell $retirement.retired_on),
                $emDash,
                (ConvertTo-CrowMarkdownCell $retirement.reason)))
            $section.Add('- **Identifier:** reserved; retired rule identifiers are never reused.')
        }
        $section.Add('')
        $section.Add((ConvertTo-CrowMarkdownText $rule.statement))
        $rationale = Get-Text (Get-CrowProperty $rule 'rationale')
        if (-not [string]::IsNullOrWhiteSpace($rationale)) {
            $section.Add('')
            $section.Add('**Rationale.** ' + (ConvertTo-CrowMarkdownText $rationale))
        }

        $citations = @(Get-Items $rule.citations)
        $section.Add('')
        $section.Add('**Implementation evidence**')
        $section.Add('')
        if ($citations.Count -eq 0) {
            $section.Add('- No implementation location was found for this rule.')
        }
        foreach ($citation in $citations) {
            $line = Get-CitationLine $citation
            $lineText = if ($null -eq $line) { '' } else { ", line $line" }
            $section.Add(('- `{0}`{1} {2} {3} (commit `{4}`)' -f
                (Get-Text $citation.path),
                $lineText,
                $emDash,
                (ConvertTo-CrowMarkdownCell $citation.symbol),
                (Get-Text $citation.commit)))
        }

        $documentationRefs = @(Get-Items $rule.documentation_refs)
        if ($documentationRefs.Count -gt 0) {
            $section.Add('')
            $section.Add(('**Documentation references:** {0}' -f
                (ConvertTo-CrowMarkdownCell ($documentationRefs -join ', '))))
        }
        $ruleSections.Add(($section -join "`n"))
    }

    $diagramSections = New-Object 'System.Collections.Generic.List[string]'
    foreach ($diagram in $diagrams) {
        $diagramId = Get-Text $diagram.id
        $ruleRefs = @(Get-Items $diagram.rule_refs | ForEach-Object { ConvertTo-CrowMarkdownCell $_ })
        $diagramSections.Add((@(
            ('### {0}' -f (ConvertTo-CrowMarkdownCell $diagram.title))
            ''
            (ConvertTo-CrowMarkdownText $diagram.description)
            ''
            ('Related rules: {0}' -f ($ruleRefs -join ', '))
            ''
            '```mermaid'
            (Get-Text $diagram.mermaid).Replace("`r`n", "`n").TrimEnd()
            '```'
        ) -join "`n"))
    }
    $diagramSection = if ($diagramSections.Count -gt 0) {
        $diagramSections -join "`n`n"
    }
    else {
        'No diagrams were produced for this scope.'
    }

    $classificationRows = New-Object 'System.Collections.Generic.List[string]'
    foreach ($classification in (Get-CrowBusinessRuleContract).Classifications) {
        $count = 0
        if ($classificationCounts.ContainsKey($classification)) {
            $count = $classificationCounts[$classification]
        }
        $classificationRows.Add(('| {0} | {1} |' -f $classification, $count))
    }
    $reconciliationSection = @(
        '| Classification | Rules |'
        '|---|---|'
        ($classificationRows -join "`n")
    ) -join "`n"

    $openQuestionSection = if ($openQuestions.Count -gt 0) {
        (@($openQuestions | ForEach-Object { '- ' + (ConvertTo-CrowMarkdownText $_) }) -join "`n")
    }
    else {
        'No open questions were recorded for this scope.'
    }

    $scopeLine = ConvertTo-CrowMarkdownText $scopeStatement
    if (-not [string]::IsNullOrWhiteSpace($scopeNote)) {
        $scopeLine += ' ' + (ConvertTo-CrowMarkdownText $scopeNote)
    }

    $markdownReplacements = [ordered]@{
        'PAGE_TITLE'              = ConvertTo-CrowMarkdownCell $displayName
        'SCOPE'                   = $scopeLine
        'REPOSITORY'              = ConvertTo-CrowMarkdownCell $repository
        'COMMIT'                  = ConvertTo-CrowMarkdownCell $commit
        'GENERATED'               = ConvertTo-CrowMarkdownCell $generated
        'RULE_COUNT'              = [string]$rules.Count
        'ACTIVE_COUNT'            = [string]$activeCount
        'RETIRED_COUNT'           = [string]$retiredCount
        'DIAGRAM_COUNT'           = [string]$diagrams.Count
        'DOCUMENTATION_SECTION'   = $documentationSection
        'FACET_SECTION'           = $facetSection
        'RULE_INDEX'              = (@(
                '| ID | Title | Category | Status | Reconciliation |'
                '|---|---|---|---|---|'
                ($indexRows -join "`n")
            ) -join "`n")
        'RULE_SECTIONS'           = ($ruleSections -join "`n`n")
        'DIAGRAM_SECTIONS'        = $diagramSection
        'RECONCILIATION_SECTION'  = $reconciliationSection
        'OPEN_QUESTIONS_SECTION'  = $openQuestionSection
    }
    $markdownDocument = Expand-CrowTemplate -Template $markdownTemplate -Values $markdownReplacements

    # ---------------------------------------------------------------------
    # HTML document
    # ---------------------------------------------------------------------
    $htmlTemplate = [System.IO.File]::ReadAllText($htmlTemplatePath)
    $css = [System.IO.File]::ReadAllText($cssPath)
    $javaScript = [System.IO.File]::ReadAllText($javaScriptPath)
    foreach ($assetPair in @(@{ Name = 'business-rules.css'; Content = $css },
            @{ Name = 'business-rules.js'; Content = $javaScript })) {
        if ($assetPair.Content -match '(?i)</\s*script') {
            throw "Bundled asset $($assetPair.Name) contains a script-closing sequence."
        }
    }

    $facetControls = New-Object 'System.Collections.Generic.List[string]'
    foreach ($group in $groups) {
        $groupId = Get-Text $group.id
        $options = New-Object 'System.Collections.Generic.List[string]'
        foreach ($facet in Get-Items $group.facets) {
            $facetId = Get-Text $facet.id
            $inputId = 'facet-' + $facetId.Replace('.', '-')
            $count = 0
            if ($facetCounts.ContainsKey($facetId)) { $count = $facetCounts[$facetId] }
            $options.Add(@"
        <li class="facet-option">
          <input type="checkbox" class="facet-input" id="$(ConvertTo-CrowHtmlText $inputId)" value="$(ConvertTo-CrowHtmlText $facetId)" data-facet="$(ConvertTo-CrowHtmlText $facetId)" data-group="$(ConvertTo-CrowHtmlText $groupId)">
          <label for="$(ConvertTo-CrowHtmlText $inputId)">$(ConvertTo-CrowHtmlText $facet.label) <span class="facet-count">($count)</span></label>
        </li>
"@)
        }
        $groupDescription = Get-Text (Get-CrowProperty $group 'description')
        $descriptionMarkup = ''
        if (-not [string]::IsNullOrWhiteSpace($groupDescription)) {
            $descriptionMarkup = "      <p class=`"facet-group__description`">$(ConvertTo-CrowHtmlText $groupDescription)</p>`n"
        }
        $facetControls.Add(@"
    <fieldset class="facet-group" data-group="$(ConvertTo-CrowHtmlText $groupId)">
      <legend>$(ConvertTo-CrowHtmlText $group.label)</legend>
$descriptionMarkup      <ul class="facet-list">
$($options -join "`n")
      </ul>
    </fieldset>
"@)
    }

    $ruleCards = New-Object 'System.Collections.Generic.List[string]'
    foreach ($rule in $rules) {
        $ruleId = Get-Text $rule.id
        $cardId = 'rule-' + $ruleId
        $classification = Get-Text $rule.reconciliation.classification
        $status = Get-Text $rule.status
        $facetRefs = @(Get-Items $rule.facets)
        $matchNotes = @{}
        foreach ($note in Get-Items (Get-CrowProperty $rule 'match_notes')) {
            $matchNotes[$note.facet] = Get-Text $note.reason
        }

        $reasonItems = New-Object 'System.Collections.Generic.List[string]'
        foreach ($facetRef in $facetRefs) {
            $reason = $facetDescriptions[$facetRef]
            if ($matchNotes.ContainsKey($facetRef)) { $reason = $matchNotes[$facetRef] }
            $reasonText = '{0}: {1}' -f $facetGroupLabels[$facetRef], $facetLabels[$facetRef]
            if (-not [string]::IsNullOrWhiteSpace($reason)) {
                $reasonText += ' ' + $emDash + ' ' + $reason
            }
            $reasonItems.Add(("        <li class=`"match-reason`" data-facet=`"$(ConvertTo-CrowHtmlText $facetRef)`">" +
                "$(ConvertTo-CrowHtmlText $reasonText)</li>"))
        }

        $citationItems = New-Object 'System.Collections.Generic.List[string]'
        foreach ($citation in Get-Items $rule.citations) {
            $line = Get-CitationLine $citation
            $lineMarkup = ''
            if ($null -ne $line) {
                $lineMarkup = " <span class=`"citation-line`">line $(ConvertTo-CrowHtmlText $line)</span>"
            }
            $citationItems.Add(("        <li><code class=`"citation-path`">$(ConvertTo-CrowHtmlText $citation.path)</code>" +
                "$lineMarkup <span class=`"citation-symbol`">$(ConvertTo-CrowHtmlText $citation.symbol)</span>" +
                " <span class=`"citation-commit`">commit $(ConvertTo-CrowHtmlText $citation.commit)</span></li>"))
        }
        if ($citationItems.Count -eq 0) {
            $citationItems.Add('        <li>No implementation location was found for this rule.</li>')
        }

        $documentationItems = New-Object 'System.Collections.Generic.List[string]'
        foreach ($documentationRef in Get-Items $rule.documentation_refs) {
            $documentationItems.Add("        <li>$(ConvertTo-CrowHtmlText $documentationRef)</li>")
        }
        $documentationMarkup = ''
        if ($documentationItems.Count -gt 0) {
            $documentationMarkup = @"
      <h4 class="rule-card__subheading">Documentation references</h4>
      <ul class="documentation-list">
$($documentationItems -join "`n")
      </ul>
"@
        }

        $rationale = Get-Text (Get-CrowProperty $rule 'rationale')
        $rationaleMarkup = ''
        if (-not [string]::IsNullOrWhiteSpace($rationale)) {
            $rationaleMarkup = "      <p class=`"rule-card__rationale`"><span class=`"meta-label`">Rationale</span> $(ConvertTo-CrowHtmlText $rationale)</p>`n"
        }
        $reconciliationNote = Get-Text (Get-CrowProperty $rule.reconciliation 'note')
        $noteMarkup = ''
        if (-not [string]::IsNullOrWhiteSpace($reconciliationNote)) {
            $noteMarkup = "      <p class=`"rule-card__note`"><span class=`"meta-label`">Reconciliation note</span> $(ConvertTo-CrowHtmlText $reconciliationNote)</p>`n"
        }
        $retirement = Get-CrowProperty $rule 'retirement'
        $retirementMarkup = ''
        if ($null -ne $retirement) {
            $retirementMarkup = "      <p class=`"rule-card__retirement`"><span class=`"meta-label`">Retired</span> $(ConvertTo-CrowHtmlText $retirement.retired_on) $emDash $(ConvertTo-CrowHtmlText $retirement.reason) The identifier stays reserved and is never reused.</p>`n"
        }

        $ruleCards.Add(@"
    <article class="rule-card" id="$(ConvertTo-CrowHtmlText $cardId)" tabindex="-1" data-rule-id="$(ConvertTo-CrowHtmlText $ruleId)" data-facets="$(ConvertTo-CrowHtmlText ($facetRefs -join ' '))" aria-labelledby="$(ConvertTo-CrowHtmlText $cardId)-title">
      <h3 class="rule-card__title" id="$(ConvertTo-CrowHtmlText $cardId)-title"><span class="rule-card__id">$(ConvertTo-CrowHtmlText $ruleId)</span> $(ConvertTo-CrowHtmlText $rule.title)</h3>
      <ul class="rule-card__meta">
        <li><span class="meta-label">Category</span> <span class="badge badge--category">$(ConvertTo-CrowHtmlText $rule.category)</span></li>
        <li><span class="meta-label">Status</span> <span class="badge badge--status-$(ConvertTo-CrowHtmlText $status)">$(ConvertTo-CrowHtmlText $status)</span></li>
        <li><span class="meta-label">Reconciliation</span> <span class="badge badge--$(ConvertTo-CrowHtmlText $classification)">$(ConvertTo-CrowHtmlText $classification)</span></li>
      </ul>
      <p class="rule-card__statement">$(ConvertTo-CrowHtmlText $rule.statement)</p>
$rationaleMarkup$noteMarkup$retirementMarkup      <button type="button" class="reasons-toggle" aria-expanded="true" aria-controls="$(ConvertTo-CrowHtmlText $cardId)-reasons" hidden>Match reasons<span class="visually-hidden"> for $(ConvertTo-CrowHtmlText $ruleId)</span></button>
      <ul class="match-reasons" id="$(ConvertTo-CrowHtmlText $cardId)-reasons">
$($reasonItems -join "`n")
      </ul>
      <h4 class="rule-card__subheading">Implementation evidence</h4>
      <ul class="citation-list">
$($citationItems -join "`n")
      </ul>
$documentationMarkup
    </article>
"@)
    }

    $diagramMarkup = New-Object 'System.Collections.Generic.List[string]'
    foreach ($diagram in $diagrams) {
        $diagramId = Get-Text $diagram.id
        $ruleRefs = @(Get-Items $diagram.rule_refs | ForEach-Object { ConvertTo-CrowHtmlText $_ })
        $diagramMarkup.Add(@"
    <figure class="diagram" id="diagram-$(ConvertTo-CrowHtmlText $diagramId)">
      <figcaption id="diagram-$(ConvertTo-CrowHtmlText $diagramId)-title">$(ConvertTo-CrowHtmlText $diagram.title)</figcaption>
      <p class="diagram__description" id="diagram-$(ConvertTo-CrowHtmlText $diagramId)-description">$(ConvertTo-CrowHtmlText $diagram.description)</p>
      <div class="diagram__canvas">
$($renderedDiagrams[$diagramId])
      </div>
      <p class="diagram__rules">Related rules: $($ruleRefs -join ', ')</p>
    </figure>
"@)
    }
    if ($diagramMarkup.Count -eq 0) {
        $diagramMarkup.Add('    <p>No diagrams were produced for this scope.</p>')
    }

    $documentationRowsHtml = New-Object 'System.Collections.Generic.List[string]'
    foreach ($source in $sources) {
        $documentationRowsHtml.Add(@"
        <tr>
          <td>$(ConvertTo-CrowHtmlText $source.id)</td>
          <td>$(ConvertTo-CrowHtmlText $source.title)</td>
          <td>$(ConvertTo-CrowHtmlText $source.kind)</td>
          <td>$(ConvertTo-CrowHtmlText $source.status)</td>
          <td>$(ConvertTo-CrowHtmlText $source.location)</td>
        </tr>
"@)
    }
    $documentationHtml = if ($documentationRowsHtml.Count -gt 0) {
        @"
      <table class="data-table">
        <caption>Documentation used for reconciliation</caption>
        <thead>
          <tr><th scope="col">Source</th><th scope="col">Title</th><th scope="col">Kind</th><th scope="col">Status</th><th scope="col">Location</th></tr>
        </thead>
        <tbody>
$($documentationRowsHtml -join "`n")
        </tbody>
      </table>
"@
    }
    else {
        '      <p>No guides, training material, or written specifications were available for this scope.</p>'
    }
    if ($gap.present) {
        $documentationHtml += @"

      <div class="notice notice--gap" role="note">
        <h3 class="notice__title">Documentation gap</h3>
        <p>$(ConvertTo-CrowHtmlText $gap.summary)</p>
        <p>$(ConvertTo-CrowHtmlText $gap.coverage_impact)</p>
      </div>
"@
    }

    $summaryItems = New-Object 'System.Collections.Generic.List[string]'
    foreach ($classification in (Get-CrowBusinessRuleContract).Classifications) {
        $count = 0
        if ($classificationCounts.ContainsKey($classification)) {
            $count = $classificationCounts[$classification]
        }
        $summaryItems.Add(@"
        <li class="summary-card">
          <span class="summary-card__value">$count</span>
          <span class="summary-card__label">$(ConvertTo-CrowHtmlText $classification)</span>
        </li>
"@)
    }

    $categoryRows = New-Object 'System.Collections.Generic.List[string]'
    foreach ($category in ($categoryCounts.Keys | Sort-Object)) {
        $categoryRows.Add(("        <tr><td>$(ConvertTo-CrowHtmlText $category)</td>" +
            "<td>$($categoryCounts[$category])</td></tr>"))
    }
    $reconciliationHtml = @"
      <table class="data-table">
        <caption>Rules by category</caption>
        <thead><tr><th scope="col">Category</th><th scope="col">Rules</th></tr></thead>
        <tbody>
$($categoryRows -join "`n")
        </tbody>
      </table>
"@

    $openQuestionsHtml = if ($openQuestions.Count -gt 0) {
        @"
      <ul class="open-questions">
$(@($openQuestions | ForEach-Object { "        <li>$(ConvertTo-CrowHtmlText $_)</li>" }) -join "`n")
      </ul>
"@
    }
    else {
        '      <p>No open questions were recorded for this scope.</p>'
    }

    $metaItems = @"
      <div class="page-meta__item"><dt>Repository</dt><dd>$(ConvertTo-CrowHtmlText $repository)</dd></div>
      <div class="page-meta__item"><dt>Commit</dt><dd>$(ConvertTo-CrowHtmlText $commit)</dd></div>
      <div class="page-meta__item"><dt>Generated</dt><dd>$(ConvertTo-CrowHtmlText $generated)</dd></div>
      <div class="page-meta__item"><dt>Rules</dt><dd>$($rules.Count) ($activeCount active, $retiredCount retired)</dd></div>
"@

    $scopeHtml = ConvertTo-CrowHtmlText $scopeStatement
    if (-not [string]::IsNullOrWhiteSpace($scopeNote)) {
        $scopeHtml += ' ' + (ConvertTo-CrowHtmlText $scopeNote)
    }

    $htmlReplacements = [ordered]@{
        'PAGE_TITLE'             = ConvertTo-CrowHtmlText ("Business rules $emDash $displayName")
        'PAGE_HEADING'           = ConvertTo-CrowHtmlText ("Business rules $emDash $displayName")
        'SCOPE_STATEMENT'        = $scopeHtml
        'META_ITEMS'             = $metaItems
        'SUMMARY_CARDS'          = ($summaryItems -join "`n")
        'DOCUMENTATION_SECTION'  = $documentationHtml
        'FACET_CONTROLS'         = ($facetControls -join "`n")
        'FILTER_STATUS'          = "Showing $($rules.Count) of $($rules.Count) rules."
        'RULE_COUNT'             = [string]$rules.Count
        'RULE_CARDS'             = ($ruleCards -join "`n")
        'DIAGRAM_SECTIONS'       = ($diagramMarkup -join "`n")
        'RECONCILIATION_SECTION' = $reconciliationHtml
        'OPEN_QUESTIONS_SECTION' = $openQuestionsHtml
        'INLINE_CSS'             = $css
        'INLINE_JS'              = $javaScript
    }
    $htmlDocument = Expand-CrowTemplate -Template $htmlTemplate -Values $htmlReplacements

    # ---------------------------------------------------------------------
    # Post-render verification
    # ---------------------------------------------------------------------
    $outputErrors = New-Object 'System.Collections.Generic.List[string]'
    Test-CrowSelfContainedHtml -Html $htmlDocument -Errors $outputErrors `
        -ExpectedInlineScript $javaScript
    Test-CrowRenderedMarkdown -Markdown $markdownDocument -Errors $outputErrors

    # Backstop only: facet element-id collisions are already rejected during data
    # validation, before any diagram is rendered. This check also covers ids that
    # originate in the pre-rendered SVG.
    $seenIdentifiers = New-Object 'System.Collections.Generic.List[string]'
    foreach ($match in [regex]::Matches($htmlDocument, '\sid\s*=\s*"([^"]+)"')) {
        $identifier = $match.Groups[1].Value
        if ($seenIdentifiers.Contains($identifier)) {
            $outputErrors.Add("Rendered HTML contains the duplicate element id '$identifier'.")
        }
        else { $seenIdentifiers.Add($identifier) }
    }

    if ($outputErrors.Count -gt 0) {
        foreach ($outputError in $outputErrors) { Write-Error $outputError -ErrorAction Continue }
        throw ("Rendered output failed verification with $($outputErrors.Count) error(s). " +
            'No output files were written.')
    }

    Write-CrowDocumentPair -Documents ([ordered]@{
            $markdownOutputPath = $markdownDocument
            $htmlOutputPath     = $htmlDocument
        })

    Write-Host "Rendered: $markdownOutputPath"
    Write-Host "Rendered: $htmlOutputPath"
    exit 0
}
catch {
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 1
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
